package main

import (
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"pds/config"
	"pds/storage"
	"pds/tm"
	"strings"
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

	// 3. Initialize Hub and the raw data stream
	hub := newHub()
	rawBroadcast := make(chan []byte, 10000)
	go hub.Run(rawBroadcast)

	// 4. Create the data bridge
	updatedParamChan := make(chan tm.ParameterValue, 5000)
	_, _ = tm.FetchFullParamsFromServer(cfg)
	go tm.GetData(cfg, updatedParamChan)

	// Relay updates to the hub for filtering
	go func() {
		for p := range updatedParamChan {
			if data, err := json.Marshal(p); err == nil {
				rawBroadcast <- data
			}
		}
	}()

	// 4. Setup Router with Middleware
	mux := http.NewServeMux()

	// Static Files (Flutter Web)
	distFS, _ := fs.Sub(webFiles, "dist")
	mux.Handle("/", http.FileServer(http.FS(distFS)))
	
	// API: Mnemonics list + metadata
	mux.HandleFunc("/mnemonics", func(w http.ResponseWriter, r *http.Request) {
		_, _ = tm.FetchFullParamsFromServer(cfg)
		var pList []tm.ParameterValue
		for _, v := range tm.GetAllParameterInfo() {
			pList = append(pList, *v)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(pList)
	})

	// API: Persistence Layer (CRUD for Pages)
	mux.HandleFunc("/api/pages", handlePagesAPI)

	// API: Status Information
	mux.HandleFunc("/api/status", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"satellite": cfg.SatelliteName,
			"connected": tm.IsConnected(),
		})
	})

	// REAL-TIME: WebSockets
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		serveWs(hub, w, r)
	})

	// GLOBAL CORS & MIME MIDDLEWARE
	corsWrapper := func(h http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
			w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, Origin")
			
			// MIME OVERRIDE: Fast-Path for font binaries
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
			h.ServeHTTP(w, r)
		})
	}

	// 5. Start Native Server on 0.0.0.0 (Network Bound)
	addr := fmt.Sprintf("0.0.0.0:%d", cfg.PortNo)
	log.Printf("[SERVER] Satellite TM Station (%s) serving on http://%s", cfg.SatelliteName, addr)
	
	if err := http.ListenAndServe(addr, corsWrapper(mux)); err != nil {
		log.Fatalf("[FATAL] Server crash: %v", err)
	}
}

func handlePagesAPI(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	switch r.Method {
	case "GET":
		pgs, err := storage.GetAllPages()
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(pgs)
	case "POST":
		var p storage.Page
		body, _ := io.ReadAll(r.Body)
		if err := json.Unmarshal(body, &p); err != nil {
			http.Error(w, "invalid payload", 400)
			return
		}
		if err := storage.SavePage(p); err != nil {
			http.Error(w, err.Error(), 500)
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
			http.Error(w, err.Error(), 500)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	default:
		http.Error(w, "method not allowed", 405)
	}
}
