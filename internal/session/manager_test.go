package session

import (
	"sync"
	"testing"
	"time"
)

func TestSessionManager_NewSession(t *testing.T) {
	mgr := NewManager()

	sessionID := mgr.NewSession()
	if sessionID == "" {
		t.Error("expected non-empty session ID")
	}

	// Create another session and ensure IDs are unique
	sessionID2 := mgr.NewSession()
	if sessionID == sessionID2 {
		t.Error("expected unique session IDs")
	}
}

func TestSessionManager_AttachContainer(t *testing.T) {
	mgr := NewManager()

	sessionID := mgr.NewSession()
	containerID := "container-123"

	err := mgr.AttachContainer(sessionID, containerID)
	if err != nil {
		t.Fatalf("AttachContainer failed: %v", err)
	}

	// Verify the container is attached
	session, exists := mgr.GetSession(sessionID)
	if !exists {
		t.Fatal("session should exist")
	}

	if session.ContainerID != containerID {
		t.Errorf("expected container ID %s, got %s", containerID, session.ContainerID)
	}
}

func TestSessionManager_AttachContainer_NonexistentSession(t *testing.T) {
	mgr := NewManager()

	err := mgr.AttachContainer("nonexistent", "container-123")
	if err == nil {
		t.Error("expected error when attaching to nonexistent session")
	}
}

func TestSessionManager_DestroySession(t *testing.T) {
	mgr := NewManager()

	sessionID := mgr.NewSession()
	mgr.AttachContainer(sessionID, "container-123")

	containerID, err := mgr.DestroySession(sessionID)
	if err != nil {
		t.Fatalf("DestroySession failed: %v", err)
	}

	if containerID != "container-123" {
		t.Errorf("expected container ID 'container-123', got %s", containerID)
	}

	// Verify session no longer exists
	_, exists := mgr.GetSession(sessionID)
	if exists {
		t.Error("session should not exist after destruction")
	}
}

func TestSessionManager_DestroySession_NonexistentSession(t *testing.T) {
	mgr := NewManager()

	_, err := mgr.DestroySession("nonexistent")
	if err == nil {
		t.Error("expected error when destroying nonexistent session")
	}
}

func TestSessionManager_ListSessions(t *testing.T) {
	mgr := NewManager()

	// Create multiple sessions
	id1 := mgr.NewSession()
	id2 := mgr.NewSession()
	id3 := mgr.NewSession()

	sessions := mgr.ListSessions()
	if len(sessions) != 3 {
		t.Errorf("expected 3 sessions, got %d", len(sessions))
	}

	// Verify all session IDs are present
	ids := map[string]bool{id1: true, id2: true, id3: true}
	for _, session := range sessions {
		if !ids[session.ID] {
			t.Errorf("unexpected session ID: %s", session.ID)
		}
		delete(ids, session.ID)
	}

	if len(ids) > 0 {
		t.Error("not all session IDs were found in list")
	}
}

func TestSessionManager_ThreadSafety(t *testing.T) {
	mgr := NewManager()
	const numGoroutines = 100

	var wg sync.WaitGroup
	wg.Add(numGoroutines)

	// Concurrently create sessions
	for i := 0; i < numGoroutines; i++ {
		go func() {
			defer wg.Done()
			sessionID := mgr.NewSession()
			mgr.AttachContainer(sessionID, "container-"+sessionID)
		}()
	}

	wg.Wait()

	sessions := mgr.ListSessions()
	if len(sessions) != numGoroutines {
		t.Errorf("expected %d sessions, got %d", numGoroutines, len(sessions))
	}
}

func TestSessionManager_UpdateActivity(t *testing.T) {
	mgr := NewManager()

	sessionID := mgr.NewSession()

	// Get initial timestamp
	session1, _ := mgr.GetSession(sessionID)
	initialTime := session1.LastActivity

	// Wait a bit and update activity
	time.Sleep(10 * time.Millisecond)
	mgr.UpdateActivity(sessionID)

	// Verify timestamp was updated
	session2, _ := mgr.GetSession(sessionID)
	if !session2.LastActivity.After(initialTime) {
		t.Error("expected LastActivity to be updated")
	}
}

func TestSessionManager_GetIdleSessions(t *testing.T) {
	mgr := NewManager()

	// Create a session and make it "old"
	id1 := mgr.NewSession()

	// Create a fresh session
	id2 := mgr.NewSession()
	mgr.UpdateActivity(id2)

	// Manually set the first session's timestamp to the past
	mgr.mu.Lock()
	if s, exists := mgr.sessions[id1]; exists {
		s.LastActivity = time.Now().Add(-20 * time.Minute)
	}
	mgr.mu.Unlock()

	// Get sessions idle for more than 15 minutes
	idle := mgr.GetIdleSessions(15 * time.Minute)

	if len(idle) != 1 {
		t.Errorf("expected 1 idle session, got %d", len(idle))
	}

	if len(idle) > 0 && idle[0].ID != id1 {
		t.Errorf("expected idle session %s, got %s", id1, idle[0].ID)
	}
}
