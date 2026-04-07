package main

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/signal"
	"pds/config"
	"pds/engine"
	"pds/storage"
	"pds/tm"
	"runtime/debug"
	"strings"
	"syscall"
	"time"
)

//go:embed dist/*
var webFiles embed.FS

func main() {
	log.SetFlags(log.Ldate | log.Ltime | log.Lshortfile)

	// 1. Load Configuration
	cfgPath := "config.json"
	if _, err := os.Stat("../config.json"); err == nil {
		cfgPath = "../config.json"
	}
	cfg, err := config.LoadConfig(cfgPath)
	if err != nil {
		log.Fatalf("[FATAL] Could not load config: %v", err)
	}

	// 2. Initialize Database persistence
	if err := storage.InitializeDB(cfg.DBPath); err != nil {
		log.Fatalf("[FATAL] Storage init failed: %v", err)
	}
	defer storage.DB.Close()

	// 3. Initialize Hub and the raw data stream
	hub := newHub()
	rawBroadcast := make(chan []byte, 10000)
	go hub.Run(rawBroadcast)

	// 4. Create the data bridge
	updatedParamChan := make(chan tm.ParameterValue, 5000)
	// Initial fetch - populate the cache once at startup
	if _, err := tm.FetchFullParamsFromServer(cfg); err != nil {
		log.Printf("[WARN] Initial parameter fetch failed: %v", err)
	}
	go tm.GetData(cfg, updatedParamChan)

	// Initialize Evaluation Engine
	evalEngine := engine.NewEngine()
	if dps, err := storage.GetAllDerivedParameters(); err == nil {
		evalEngine.Reload(dps)
	}

	// Relay updates to the hub for filtering
	go func() {
		for p := range updatedParamChan {
			if data, err := json.Marshal(p); err == nil {
				rawBroadcast <- data
			}

			// Pipeline trigger for Phase 3/4
			if derivedParams, err := evalEngine.Evaluate(p); err == nil {
				for _, dp := range derivedParams {
					if data, err := json.Marshal(dp); err == nil {
						rawBroadcast <- data
					}
				}
			}
		}
	}()

	// 5. Setup Router with Middleware
	mux := http.NewServeMux()

	// Static Files (Flutter Web)
	distFS, _ := fs.Sub(webFiles, "dist")
	mux.Handle("/", http.FileServer(http.FS(distFS)))

	// API: Mnemonics list + metadata
	mux.HandleFunc("/mnemonics", func(w http.ResponseWriter, r *http.Request) {
		var pList []tm.ParameterValue
		
		// 1. Load physical parameters
		for _, v := range tm.GetAllParameterInfo() {
			pList = append(pList, v)
		}
		
		// 2. Synthesize derived parameters into the list
		if dps, err := storage.GetAllDerivedParameters(); err == nil {
			for _, d := range dps {
				pList = append(pList, tm.ParameterValue{
					Mnemonic: d.Mnemonic,
					Units:    d.Unit,
				})
			}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(pList)
	})

	// API: Persistence Layer (CRUD for Pages)
	mux.HandleFunc("/api/pages", handlePagesAPI)

	// API: Persistence Layer (CRUD for Derived Parameters)
	mux.HandleFunc("/api/derived", func(w http.ResponseWriter, r *http.Request) {
		handleDerivedAPI(w, r, evalEngine)
	})

	// API: Status Information
	mux.HandleFunc("/api/status", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"satellite": cfg.SatelliteName,
			"connected": tm.IsConnected(),
			"state":     tm.GetConnectionState(), // Numeric value of State enum
			"ribbon":    cfg.RibbonMnemonics,
		})
	})

	// REAL-TIME: WebSockets
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		serveWs(hub, w, r)
	})

	// Wrap mux with robustness middleware
	handler := RecoveryMiddleware(CorsMiddleware(mux))

	// 6. Start Server with Graceful Shutdown
	addr := fmt.Sprintf("0.0.0.0:%d", cfg.PortNo)
	srv := &http.Server{
		Addr:         addr,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Run server in a goroutine
	go func() {
		log.Printf("[SERVER] Satellite TM Station (%s) serving on http://%s", cfg.SatelliteName, addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[FATAL] Listen error: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("[SERVER] Shutting down...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("[FATAL] Server forced to shutdown: %v", err)
	}

	log.Println("[SERVER] Exited nicely")
}

// RecoveryMiddleware catches panics and prevents server crash
func RecoveryMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				log.Printf("[PANIC] %v\n%s", err, debug.Stack())
				http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// CorsMiddleware handles CORS and special MIME types
func CorsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
		w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, Origin")

		// MIME OVERRIDE for Flutter Web assets
		path := strings.ToLower(r.URL.Path)
		if strings.HasSuffix(path, ".ttf") {
			w.Header().Set("Content-Type", "font/ttf")
		} else if strings.HasSuffix(path, ".wasm") {
			w.Header().Set("Content-Type", "application/wasm")
		}

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func handlePagesAPI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	switch r.Method {
	case "GET":
		pgs, err := storage.GetAllPages()
		if err != nil {
			http.Error(w, "failed to fetch pages", 500)
			return
		}
		json.NewEncoder(w).Encode(pgs)
	case "POST":
		var p storage.Page
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "failed to read body", 400)
			return
		}
		if err := json.Unmarshal(body, &p); err != nil {
			http.Error(w, "invalid payload", 400)
			return
		}
		if err := storage.SavePage(p); err != nil {
			http.Error(w, "failed to save page", 500)
			return
		}
		w.WriteHeader(http.StatusCreated)
	case "DELETE":
		id := r.URL.Query().Get("id")
		if id == "" {
			http.Error(w, "missing id", 400)
			return
		}
		if err := storage.DeletePage(id); err != nil {
			http.Error(w, "failed to delete page", 500)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		http.Error(w, "method not allowed", 405)
	}
}

func handleDerivedAPI(w http.ResponseWriter, r *http.Request, eng *engine.Engine) {
	w.Header().Set("Content-Type", "application/json")
	switch r.Method {
	case "GET":
		dps, err := storage.GetAllDerivedParameters()
		if err != nil {
			http.Error(w, "failed to fetch derived parameters", 500)
			return
		}
		json.NewEncoder(w).Encode(dps)
	case "POST":
		var dp storage.DerivedParameter
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "failed to read body", 400)
			return
		}
		if err := json.Unmarshal(body, &dp); err != nil {
			http.Error(w, "invalid payload", 400)
			return
		}
		if err := storage.SaveDerivedParameter(dp); err != nil {
			http.Error(w, "failed to save derived parameter", 500)
			return
		}
		
		if dps, err := storage.GetAllDerivedParameters(); err == nil {
			eng.Reload(dps)
		}
		
		w.WriteHeader(http.StatusCreated)
	case "DELETE":
		id := r.URL.Query().Get("id")
		if id == "" {
			http.Error(w, "missing id", 400)
			return
		}
		if err := storage.DeleteDerivedParameter(id); err != nil {
			http.Error(w, "failed to delete derived parameter", 500)
			return
		}
		
		if dps, err := storage.GetAllDerivedParameters(); err == nil {
			eng.Reload(dps)
		}

		w.WriteHeader(http.StatusNoContent)
	default:
		http.Error(w, "method not allowed", 405)
	}
}
