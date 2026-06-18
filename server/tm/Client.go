package tm

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"pds/config"
	"strconv"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	pingPeriod = 5 * time.Second
	pongWait   = 10 * time.Second
)

type SafeParameter struct {
	mu  sync.RWMutex
	val ParameterValue
}

var (
	paramCache         map[string]parameter
	parameterMnemonics []string
	paramCacheOnce     sync.Once
	paramCacheErr      error
	paramValueMap      map[string]*SafeParameter
	paramMu            sync.RWMutex
)

func getParamCache(conf *config.Config) (map[string]parameter, error) {
	paramCacheOnce.Do(func() {
		paramCache, paramCacheErr = FetchFullParamsFromServer(conf)
	})
	return paramCache, paramCacheErr
}

func FetchFullParamsFromServer(cfg *config.Config) (map[string]parameter, error) {
	cachePath := config.ExpandPath(cfg.MnemonicCachePath)
	
	// Ensure directory exists
	dir := filepath.Dir(cachePath)
	_ = os.MkdirAll(dir, 0755)

	u := "http://" + cfg.TMServer.IP + fmt.Sprintf(":%d", cfg.TMServer.PortNo) + "/pid_info?sc_id=" + cfg.SatelliteName
	resp, err := http.Get(u)
	
	var data []byte
	if err == nil {
		defer resp.Body.Close()
		if resp.StatusCode == http.StatusOK {
			data, err = io.ReadAll(resp.Body)
			if err == nil {
				// Success - save to cache
				_ = os.WriteFile(cachePath, data, 0644)
				log.Printf("[TM] Mnemonic list updated and cached to %s", cachePath)
			}
		} else {
			err = fmt.Errorf("bad status: %s", resp.Status)
		}
	}

	// If fetch failed, try to load from cache
	if err != nil {
		log.Printf("[WARN] Failed to fetch mnemonics from server: %v. Attempting to load from cache...", err)
		data, err = os.ReadFile(cachePath)
		if err != nil {
			return nil, fmt.Errorf("failed to fetch from server and no cache found: %v", err)
		}
		log.Printf("[TM] Loaded mnemonics from local cache: %s", cachePath)
	}

	var params []parameter
	if err := json.Unmarshal(data, &params); err != nil {
		return nil, err
	}

	paramMu.Lock()
	defer paramMu.Unlock()

	paramCache = make(map[string]parameter)
	paramValueMap = make(map[string]*SafeParameter)
	parameterMnemonics = make([]string, 0)

	for _, p := range params {
		paramCache[p.PID] = p
		paramValueMap[p.PID] = &SafeParameter{
			val: ParameterValue{
				Mnemonic:   p.Mnemonic,
				Units:      p.Units,
				TM1Value:   "",
				TM2Value:   "",
				TM1Count:   "",
				TM2Count:   "",
				UpperLimit: p.UpperLimit,
				LowerLimit: p.LowerLimit,
				Tolerance:  p.Tolerance,
			},
		}
		parameterMnemonics = append(parameterMnemonics, p.Mnemonic)
	}
	return paramCache, nil
}

func subscribeToAllMnemonics(conf *config.Config, stream string, output chan<- Parameter) {
	for {
		_, err := getParamCache(conf)
		if err != nil {
			log.Printf("[TM-%s] Cache not available, retrying in 5s...", stream)
			time.Sleep(5 * time.Second)
			continue
		}

		addr := conf.TMServer.IP + ":" + strconv.Itoa(conf.TMServer.PortNo)
		u := url.URL{Scheme: "ws", Host: addr, Path: conf.TMServer.Path}

		log.Printf("[TM-%s] Attempting connection to %s...", stream, u.String())
		conn, _, err := websocket.DefaultDialer.Dial(u.String(), nil)
		if err != nil {
			SetConnected(false)
			log.Printf("[TM-%s] Connection failed: %v. Retrying in 5s...", stream, err)
			time.Sleep(5 * time.Second)
			continue
		}

		SetConnected(true)
		runSubscription(conf, stream, conn, output)

		// If runSubscription returns, it means the connection was lost
		SetConnected(false)
		log.Printf("[TM-%s] Connection lost. Retrying in 5s...", stream)
		time.Sleep(5 * time.Second)
	}
}

func runSubscription(conf *config.Config, stream string, conn *websocket.Conn, output chan<- Parameter) {
	defer conn.Close()

	// Setup Heartbeat
	conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(pongWait))
		MarkHeartbeatReceived()
		return nil
	})

	// Ping Loop
	pingCtx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go func() {
		ticker := time.NewTicker(pingPeriod)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
					return
				}
			case <-pingCtx.Done():
				return
			}
		}
	}()

	req := request{
		UserID:   "PDS",
		MsgType:  "ntm",
		OnChange: true,
		MsgPayload: messagePayload{
			ScID:       conf.SatelliteName,
			Stream:     "ANY-" + stream,
			Action:     "subscribe",
			Parameters: []string{"*"},
		},
	}

	if err := conn.WriteJSON(req); err != nil {
		log.Printf("[TM-%s] Subscription request failed: %v", stream, err)
		return
	}

	for {
		var resp response
		if err := conn.ReadJSON(&resp); err != nil {
			log.Printf("[TM-%s] Read error: %v", stream, err)
			return
		}

		MarkPacketReceived()
		for _, pInfo := range resp.MsgPayload.ParametersInfo {
			output <- pInfo
		}
	}
}

func GetAllParameterInfo() map[string]ParameterValue {
	paramMu.RLock()
	defer paramMu.RUnlock()

	result := make(map[string]ParameterValue, len(paramValueMap))
	for k, sp := range paramValueMap {
		sp.mu.RLock()
		result[k] = sp.val
		sp.mu.RUnlock()
	}
	return result
}

func UpdateParamValue(pid string, tm1Val string, tm2Val string, count string, isTM1 bool) (*ParameterValue, bool) {
	paramMu.RLock()
	sp, ok := paramValueMap[pid]
	paramMu.RUnlock()

	if !ok {
		return nil, false
	}

	sp.mu.Lock()
	defer sp.mu.Unlock()

	if isTM1 {
		sp.val.TM1Value = tm1Val
		sp.val.TM1Count = count
	} else {
		sp.val.TM2Value = tm2Val
		sp.val.TM2Count = count
	}

	copied := sp.val
	return &copied, true
}
