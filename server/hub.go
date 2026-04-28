package main

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  2048,
	WriteBufferSize: 2048,
	CheckOrigin:     func(r *http.Request) bool { return true },
}

const (
	writeWait = 10 * time.Second
	pongWait = 60 * time.Second
	pingPeriod = (pongWait * 9) / 10
	maxMessageSize = 8192
)

// Client represents a single web browser connection
type Client struct {
	hub *Hub
	conn *websocket.Conn
	
	// Set of mnemonics this client wants to see
	subscriptions map[string]bool
	mu            sync.RWMutex
	
	send chan []byte
}

type SubscriptionMessage struct {
	Type      string   `json:"type"` // "subscribe"
	Mnemonics []string `json:"mnemonics"`
}

type MnemonicHeader struct {
	Mnemonic string `json:"mnemonic"`
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error { c.conn.SetReadDeadline(time.Now().Add(pongWait)); return nil })
	
	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("error: %v", err)
			}
			break
		}
		
		var sub SubscriptionMessage
		if err := json.Unmarshal(message, &sub); err == nil && sub.Type == "subscribe" {
			c.mu.Lock()
			c.subscriptions = make(map[string]bool)
			for _, m := range sub.Mnemonics {
				c.subscriptions[m] = true
			}
			c.mu.Unlock()
			log.Printf("[WS] Subscription update: %d items", len(sub.Mnemonics))
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Add queued chat messages to the current websocket message.
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte("\n"))
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

type Hub struct {
	clients    map[*Client]bool
	register   chan *Client
	unregister chan *Client
}

func newHub() *Hub {
	return &Hub{
		register:   make(chan *Client),
		unregister: make(chan *Client),
		clients:    make(map[*Client]bool),
	}
}

func (h *Hub) Run(rawUpdateChan <-chan []byte) {
	for {
		select {
		case client := <-h.register:
			h.clients[client] = true
		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
		case msg := <-rawUpdateChan:
			var header MnemonicHeader
			if err := json.Unmarshal(msg, &header); err != nil {
				continue
			}
			
			if header.Mnemonic == "" {
				continue
			}

			for client := range h.clients {
				client.mu.RLock()
				subscribed := client.subscriptions[header.Mnemonic]
				client.mu.RUnlock()
				
				if subscribed {
					select {
					case client.send <- msg:
					default:
						// Already handled by closing and deleting in h.unregister
					}
				}
			}
		}
	}
}

func serveWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WS] Upgrade error: %v", err)
		return
	}
	client := &Client{
		hub:           hub,
		conn:          conn,
		send:          make(chan []byte, 2048),
		subscriptions: make(map[string]bool),
	}
	hub.register <- client
	go client.writePump()
	go client.readPump()
}
