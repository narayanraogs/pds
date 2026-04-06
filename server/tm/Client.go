package tm

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"pds/config"
	"strconv"
	"sync"

	"github.com/gorilla/websocket"
)

var (
	paramCache         map[string]parameter
	parameterMnemonics []string
	paramCacheOnce     sync.Once
	paramCacheErr      error
	paramValueMap      map[string]*ParameterValue
)

func getParamCache(conf *config.Config) (map[string]parameter, error) {
	paramCacheOnce.Do(func() {
		paramCache, paramCacheErr = FetchFullParamsFromServer(conf)
	})
	return paramCache, paramCacheErr
}

func FetchFullParamsFromServer(cfg *config.Config) (map[string]parameter, error) {
	u := "http://" + cfg.TMServer.IP + fmt.Sprintf(":%d", cfg.TMServer.PortNo) + "/pid_info?sc_id=" + cfg.SatelliteName
	resp, err := http.Get(u)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	parameterMnemonics = make([]string, 0)

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("bad status: %s", resp.Status)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var params []parameter
	if err := json.Unmarshal(body, &params); err != nil {
		return nil, err
	}

	paramCache := make(map[string]parameter)
	paramValueMap = make(map[string]*ParameterValue)
	for _, p := range params {
		paramCache[p.PID] = p
		paramValueMap[p.PID] = &ParameterValue{
			Mnemonic:   p.Mnemonic,
			Units:      p.Units,
			TM1Value:   "",
			TM2Value:   "",
			UpperLimit: p.UpperLimit,
			LowerLimit: p.LowerLimit,
			Tolerance:  p.Tolerance,
		}
		parameterMnemonics = append(parameterMnemonics, p.Mnemonic)
	}
	return paramCache, nil
}

func subscribeToAllMnemonics(conf *config.Config, stream string, output chan<- Parameter) {
	_, err := getParamCache(conf)
	if err != nil {
		var param Parameter
		param.Error = "Param Cache Not loaded"
		param.OK = false
		param.Param = "ALL"
		output <- param
		close(output)
	}

	addr := conf.TMServer.IP + ":" + strconv.Itoa(conf.TMServer.PortNo)
	u := url.URL{Scheme: "ws", Host: addr, Path: conf.TMServer.Path}
	conn, _, err := websocket.DefaultDialer.Dial(u.String(), nil)
	if err != nil {
		SetConnected(false)
		var param Parameter
		param.Error = "TM server unavailable: " + err.Error()
		param.OK = false
		param.Param = "ALL"
		output <- param
		close(output)
		return
	}
	SetConnected(true)
	defer conn.Close()
	defer SetConnected(false)

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
		var param Parameter
		param.Error = "Failed to send subscription request: " + err.Error()
		param.OK = false
		param.Param = "ALL"
		output <- param
		close(output)
		return
	}

	for {
		var resp response
		if err := conn.ReadJSON(&resp); err != nil {
			SetConnected(false)
			var param Parameter
			param.Error = "Connection read error: " + err.Error()
			param.OK = false
			param.Param = "ALL"
			output <- param
			close(output)
			return
		}

		MarkPacketReceived()
		for _, pInfo := range resp.MsgPayload.ParametersInfo {
			output <- pInfo
		}

	}

}

func GetAllParameterInfo() map[string]*ParameterValue {
	return paramValueMap
}
