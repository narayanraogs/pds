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

// Optimization: Use a small struct for faster parsing during filtering
type MnemonicHeader struct {
	Mnemonic string `json:"mnemonic"`
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	
	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			break
		}
		
		var sub SubscriptionMessage
		if err := json.Unmarshal(message, &sub); err == nil && sub.Type == "subscribe" {
			c.mu.Lock()
			// Reset and apply new interests
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
	ticker := time.NewTicker(45 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case message, ok := <-c.send:
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			c.conn.WriteMessage(websocket.TextMessage, message)
		case <-ticker.C:
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

type Hub struct {
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
}

func newHub() *Hub {
	return &Hub{
		broadcast:  make(chan []byte, 10000), // Buffered to handle peaks
		register:   make(chan *Client),
		unregister: make(chan *Client),
		clients:    make(map[*Client]bool),
	}
}

func (h *Hub) Run(rawUpdateChan <-chan []byte) {
	go h.listenToClients()
	
	for msg := range rawUpdateChan {
		// FAST FILTERING: Typed parse instead of map[string]interface{}
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
					// Drop if writing to browser is too slow to avoid blocking the whole server
				}
			}
		}
	}
}

func (h *Hub) listenToClients() {
	for {
		select {
		case client := <-h.register:
			h.clients[client] = true
		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
		}
	}
}

func serveWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	client := &Client{
		hub:           hub,
		conn:          conn,
		send:          make(chan []byte, 2048), // Large buffer for bursts
		subscriptions: make(map[string]bool),
	}
	hub.register <- client
	go client.writePump()
	go client.readPump()
}
