package tm

import (
	"sync/atomic"
	"time"
)

var (
	connectionStatus int32 // 0 for disconnected, 1 for connected
	lastHeartbeatUnix int64 // Unix timestamp of last pong or data
	lastDataUnix      int64 // Unix timestamp of last actual telemetry packet
)

type ConnectionState int

const (
	StateDisconnected ConnectionState = iota
	StateConnected                    // TCP Connected and heartbeats ok, but no telemetry data
	StateLive                         // Telemetry data is actively flowing
)

func SetConnected(status bool) {
	if status {
		atomic.StoreInt32(&connectionStatus, 1)
		now := time.Now().Unix()
		atomic.StoreInt64(&lastHeartbeatUnix, now)
		// We don't update lastDataUnix here to keep it stale if no data arrived yet
	} else {
		atomic.StoreInt32(&connectionStatus, 0)
	}
}

func GetConnectionState() ConnectionState {
	status := atomic.LoadInt32(&connectionStatus)
	if status == 0 {
		return StateDisconnected
	}
	
	now := time.Now().Unix()
	lastHeartbeat := atomic.LoadInt64(&lastHeartbeatUnix)
	lastData := atomic.LoadInt64(&lastDataUnix)
	
	// 1. If we haven't even had a heartbeat in 10s, consider it disconnected/stale link
	if (now - lastHeartbeat) > 10 {
		return StateDisconnected 
	}
	
	// 2. If we have heartbeats but no data for 10s, it's "Connected" (User's 'STALE')
	if (now - lastData) > 10 {
		return StateConnected
	}
	
	// 3. Otherwise, we have recent data
	return StateLive
}

func IsConnected() bool {
	return atomic.LoadInt32(&connectionStatus) == 1
}

func MarkHeartbeatReceived() {
	atomic.StoreInt64(&lastHeartbeatUnix, time.Now().Unix())
}

func MarkPacketReceived() {
	now := time.Now().Unix()
	atomic.StoreInt64(&lastHeartbeatUnix, now)
	atomic.StoreInt64(&lastDataUnix, now)
	atomic.StoreInt32(&connectionStatus, 1)
}
