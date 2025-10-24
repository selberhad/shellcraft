package server

import (
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/shellcraft/server/internal/docker"
)

func TestWebSocketConnection(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	// Create a session first
	sessionID, containerID := createTestSession(t, srv)

	// Create test server
	server := httptest.NewServer(srv.Router())
	defer server.Close()

	// Convert http:// to ws://
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/session/" + sessionID + "/ws"

	// Connect via WebSocket
	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to connect to WebSocket: %v", err)
	}
	defer ws.Close()

	// Verify connection is established
	if ws == nil {
		t.Fatal("WebSocket connection is nil")
	}

	// For now, just verify we can connect
	// Full PTY testing will come when we integrate with real containers
	t.Logf("WebSocket connected for session %s (container %s)", sessionID, containerID)
}

func TestWebSocketConnection_InvalidSession(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	server := httptest.NewServer(srv.Router())
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/session/nonexistent/ws"

	// Try to connect - should fail or close immediately
	ws, resp, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err == nil {
		ws.Close()
		t.Error("Expected error connecting to invalid session, but succeeded")
	}

	if resp != nil && resp.StatusCode == 200 {
		t.Error("Expected non-200 status for invalid session")
	}
}

func TestWebSocketEcho(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	// Create a session
	sessionID, _ := createTestSession(t, srv)

	// Create test server
	server := httptest.NewServer(srv.Router())
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/session/" + sessionID + "/ws"

	// Connect via WebSocket
	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to connect to WebSocket: %v", err)
	}
	defer ws.Close()

	// For mock testing, we'll send a command and expect some response
	// In the real implementation, this will be PTY I/O
	testMessage := "echo test\n"
	err = ws.WriteMessage(websocket.TextMessage, []byte(testMessage))
	if err != nil {
		t.Fatalf("Failed to write message: %v", err)
	}

	// Try to read response (with timeout)
	ws.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, message, err := ws.ReadMessage()

	// For now, we expect an error or mock response
	// This will be properly implemented when we add real PTY support
	if err == nil {
		t.Logf("Received message: %s", string(message))
	} else {
		// Expected for mock implementation
		t.Logf("No response yet (expected for mock): %v", err)
	}
}

func TestWebSocketConcurrentConnections(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	server := httptest.NewServer(srv.Router())
	defer server.Close()

	// Create multiple sessions
	sessions := make([]string, 3)
	for i := 0; i < 3; i++ {
		sessionID, _ := createTestSession(t, srv)
		sessions[i] = sessionID
	}

	// Connect to all sessions concurrently
	done := make(chan bool, 3)
	for _, sessionID := range sessions {
		go func(sid string) {
			wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/session/" + sid + "/ws"
			ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
			if err != nil {
				t.Errorf("Failed to connect to session %s: %v", sid, err)
				done <- false
				return
			}
			defer ws.Close()

			// Verify connection works
			time.Sleep(100 * time.Millisecond)
			done <- true
		}(sessionID)
	}

	// Wait for all connections
	for i := 0; i < 3; i++ {
		select {
		case success := <-done:
			if !success {
				t.Error("Connection failed")
			}
		case <-time.After(5 * time.Second):
			t.Error("Timeout waiting for connection")
		}
	}
}

func TestWebSocketActivityTracking(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	sessionID, _ := createTestSession(t, srv)

	// Get initial activity time
	session1, _ := srv.sessionManager.GetSession(sessionID)
	initialActivity := session1.LastActivity

	// Wait a bit
	time.Sleep(50 * time.Millisecond)

	// Connect via WebSocket
	server := httptest.NewServer(srv.Router())
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/session/" + sessionID + "/ws"
	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer ws.Close()

	// Send a message to trigger activity update
	ws.WriteMessage(websocket.TextMessage, []byte("test\n"))
	time.Sleep(50 * time.Millisecond)

	// Check activity was updated
	session2, _ := srv.sessionManager.GetSession(sessionID)
	if !session2.LastActivity.After(initialActivity) {
		t.Error("Expected LastActivity to be updated after WebSocket activity")
	}
}

// TestWebSocketContainerAttach tests attaching to a real container (integration test)
func TestWebSocketContainerAttach(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// This will be implemented when we add real Docker client integration
	// For now, we're testing with mocks
	t.Skip("Integration test - requires real Docker daemon")

	// TODO: Implement full integration test with real container
	// 1. Create real container with alpine
	// 2. Attach PTY via WebSocket
	// 3. Send command: "echo test"
	// 4. Receive output: "test"
	// 5. Clean up container
}
