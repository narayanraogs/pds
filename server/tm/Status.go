package tm

import (
	"sync/atomic"
	"time"
)

var (
	connectionStatus int32 // 0 for disconnected, 1 for connected
	lastPacketUnix   int64 // Unix timestamp
)

func SetConnected(status bool) {
	if status {
		atomic.StoreInt32(&connectionStatus, 1)
		atomic.StoreInt64(&lastPacketUnix, time.Now().Unix())
	} else {
		atomic.StoreInt32(&connectionStatus, 0)
	}
}

func IsConnected() bool {
	status := atomic.LoadInt32(&connectionStatus)
	last := atomic.LoadInt64(&lastPacketUnix)
	
	// If marked as connected but we haven't seen anything in 10 seconds, it's dead
	if status == 1 && (time.Now().Unix()-last) > 10 {
		return false
	}
	
	return status == 1
}

func MarkPacketReceived() {
	// Zero-lock atomic update
	atomic.StoreInt64(&lastPacketUnix, time.Now().Unix())
	atomic.StoreInt32(&connectionStatus, 1)
}
