package main

import (
	"sync"

	"github.com/gorilla/websocket"
)

// ConnectionManager fans out messages to WebSocket connections per
// conversation. In-memory, single-process -- fine for a small closed beta
// (roadmap.md Phase 1); revisit if the relay needs to scale past one process.
type ConnectionManager struct {
	mu    sync.Mutex
	conns map[uint][]*websocket.Conn
}

func newConnectionManager() *ConnectionManager {
	return &ConnectionManager{conns: make(map[uint][]*websocket.Conn)}
}

func (m *ConnectionManager) add(conversationID uint, conn *websocket.Conn) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.conns[conversationID] = append(m.conns[conversationID], conn)
}

func (m *ConnectionManager) remove(conversationID uint, conn *websocket.Conn) {
	m.mu.Lock()
	defer m.mu.Unlock()
	peers := m.conns[conversationID]
	for i, c := range peers {
		if c == conn {
			m.conns[conversationID] = append(peers[:i], peers[i+1:]...)
			break
		}
	}
}

func (m *ConnectionManager) broadcast(conversationID uint, payload interface{}) {
	m.mu.Lock()
	peers := append([]*websocket.Conn(nil), m.conns[conversationID]...)
	m.mu.Unlock()

	for _, c := range peers {
		_ = c.WriteJSON(payload)
	}
}
