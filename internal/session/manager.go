package session

import (
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"
)

// Session represents a player session
type Session struct {
	ID           string
	ContainerID  string
	CreatedAt    time.Time
	LastActivity time.Time
}

// Manager handles session lifecycle and state
type Manager struct {
	mu       sync.RWMutex
	sessions map[string]*Session
}

// NewManager creates a new session manager
func NewManager() *Manager {
	return &Manager{
		sessions: make(map[string]*Session),
	}
}

// NewSession creates a new session and returns its unique ID
func (m *Manager) NewSession() string {
	m.mu.Lock()
	defer m.mu.Unlock()

	sessionID := uuid.New().String()
	now := time.Now()

	m.sessions[sessionID] = &Session{
		ID:           sessionID,
		CreatedAt:    now,
		LastActivity: now,
	}

	return sessionID
}

// AttachContainer associates a container with a session
func (m *Manager) AttachContainer(sessionID, containerID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	session, exists := m.sessions[sessionID]
	if !exists {
		return fmt.Errorf("session %s not found", sessionID)
	}

	session.ContainerID = containerID
	session.LastActivity = time.Now()

	return nil
}

// DestroySession removes a session and returns the associated container ID
func (m *Manager) DestroySession(sessionID string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	session, exists := m.sessions[sessionID]
	if !exists {
		return "", fmt.Errorf("session %s not found", sessionID)
	}

	containerID := session.ContainerID
	delete(m.sessions, sessionID)

	return containerID, nil
}

// GetSession retrieves a session by ID
func (m *Manager) GetSession(sessionID string) (*Session, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	session, exists := m.sessions[sessionID]
	if !exists {
		return nil, false
	}

	// Return a copy to prevent external modification
	sessionCopy := *session
	return &sessionCopy, true
}

// ListSessions returns all active sessions
func (m *Manager) ListSessions() []*Session {
	m.mu.RLock()
	defer m.mu.RUnlock()

	sessions := make([]*Session, 0, len(m.sessions))
	for _, session := range m.sessions {
		sessionCopy := *session
		sessions = append(sessions, &sessionCopy)
	}

	return sessions
}

// UpdateActivity updates the last activity timestamp for a session
func (m *Manager) UpdateActivity(sessionID string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if session, exists := m.sessions[sessionID]; exists {
		session.LastActivity = time.Now()
	}
}

// GetIdleSessions returns sessions that have been idle for longer than the specified duration
func (m *Manager) GetIdleSessions(idleDuration time.Duration) []*Session {
	m.mu.RLock()
	defer m.mu.RUnlock()

	cutoff := time.Now().Add(-idleDuration)
	var idleSessions []*Session

	for _, session := range m.sessions {
		if session.LastActivity.Before(cutoff) {
			sessionCopy := *session
			idleSessions = append(idleSessions, &sessionCopy)
		}
	}

	return idleSessions
}

// SetLastActivity manually sets the last activity time for a session (for testing)
func (m *Manager) SetLastActivity(sessionID string, t time.Time) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if session, exists := m.sessions[sessionID]; exists {
		session.LastActivity = t
	}
}
