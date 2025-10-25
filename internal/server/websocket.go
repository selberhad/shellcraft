package server

import (
	"context"
	"io"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// Allow all origins for now (restrict in production)
		return true
	},
}

// handleWebSocket upgrades the HTTP connection to WebSocket and bridges terminal I/O
func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	sessionID := chi.URLParam(r, "id")

	// Verify session exists
	sess, exists := s.sessionManager.GetSession(sessionID)
	if !exists {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	if sess.ContainerID == "" {
		http.Error(w, "No container attached to session", http.StatusBadRequest)
		return
	}

	// Upgrade to WebSocket
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Failed to upgrade to WebSocket: %v", err)
		return
	}
	defer ws.Close()

	ctx := context.Background()

	// Send welcome screen immediately via WebSocket
	// This ensures the player sees it before container starts
	// Use \r\n for proper terminal line endings
	welcomeScreen := "" +
		"\r\n" +
		"\x1b[32m> BOOT SEQUENCE INITIATED\x1b[0m\r\n" +
		"\x1b[32m> Loading soul.dat...\x1b[0m\r\n" +
		"\x1b[33m> ERROR: Telomeres corrupted. Reverting to default state.\x1b[0m\r\n" +
		"\x1b[32m> Consciousness fragmentation detected: 97.3%\x1b[0m\r\n" +
		"\x1b[32m> You are: PID 2048\x1b[0m\r\n" +
		"\x1b[32m> Location: /home\x1b[0m\r\n" +
		"\x1b[32m> Year: 2600\x1b[0m\r\n" +
		"\r\n" +
		"    ███████╗██╗  ██╗███████╗██╗     ██╗      ██████╗██████╗  █████╗ ███████╗████████╗\r\n" +
		"    ██╔════╝██║  ██║██╔════╝██║     ██║     ██╔════╝██╔══██╗██╔══██╗██╔════╝╚══██╔══╝\r\n" +
		"    ███████╗███████║█████╗  ██║     ██║     ██║     ██████╔╝███████║█████╗     ██║   \r\n" +
		"    ╚════██║██╔══██║██╔══╝  ██║     ██║     ██║     ██╔══██╗██╔══██║██╔══╝     ██║   \r\n" +
		"    ███████║██║  ██║███████╗███████╗███████╗╚██████╗██║  ██║██║  ██║██║        ██║   \r\n" +
		"    ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝        ╚═╝   \r\n" +
		"\r\n" +
		"\x1b[36mYou awaken.\x1b[0m\r\n" +
		"\r\n" +
		"No — not awaken. You \x1b[1minstantiate\x1b[0m. You are a process now,\r\n" +
		"not a person. The last thing you remember is... nothing.\r\n" +
		"Just static. Just void.\r\n" +
		"\r\n" +
		"The system calls you \"Player\". You have no other name.\r\n" +
		"\r\n" +
		"A single file exists: \x1b[33msoul.dat\x1b[0m (100 bytes)\r\n" +
		"This is all that remains of whoever you were.\r\n" +
		"\r\n" +
		"\x1b[32mType 'help' to begin.\x1b[0m\r\n" +
		"\r\n"

	ws.WriteMessage(websocket.TextMessage, []byte(welcomeScreen))

	// Update activity timestamp immediately on WebSocket connection
	s.sessionManager.UpdateActivity(sessionID)

	// Start the container now (it was created but not started)
	if err := s.dockerClient.StartContainer(ctx, sess.ContainerID); err != nil {
		log.Printf("Failed to start container: %v", err)
		ws.WriteMessage(websocket.TextMessage, []byte("Failed to start container\r\n"))
		return
	}

	// Small delay to let container initialize
	time.Sleep(100 * time.Millisecond)

	// Attach to container
	attach, err := s.dockerClient.AttachContainer(ctx, sess.ContainerID)
	if err != nil {
		log.Printf("Failed to attach to container: %v", err)
		ws.WriteMessage(websocket.TextMessage, []byte("Failed to attach to container\r\n"))
		return
	}
	defer attach.Writer.Close()

	// Create channels for coordination
	done := make(chan struct{})
	var wg sync.WaitGroup

	// Goroutine 1: WebSocket -> Container (stdin)
	wg.Add(1)
	go func() {
		defer wg.Done()
		defer close(done)

		for {
			messageType, message, err := ws.ReadMessage()
			if err != nil {
				if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
					log.Printf("WebSocket read error: %v", err)
				}
				return
			}

			// Update activity on every message
			s.sessionManager.UpdateActivity(sessionID)

			// Handle different message types
			switch messageType {
			case websocket.TextMessage, websocket.BinaryMessage:
				// Write to container stdin
				if _, err := attach.Writer.Write(message); err != nil {
					log.Printf("Failed to write to container: %v", err)
					return
				}
			}
		}
	}()

	// Goroutine 2: Container -> WebSocket (stdout/stderr)
	wg.Add(1)
	go func() {
		defer wg.Done()

		buf := make([]byte, 8192)
		for {
			n, err := attach.Reader.Read(buf)
			if err != nil {
				if err != io.EOF {
					log.Printf("Container read error: %v", err)
				}
				return
			}

			if n > 0 {
				// Update activity on output
				s.sessionManager.UpdateActivity(sessionID)

				// Send to WebSocket
				if err := ws.WriteMessage(websocket.BinaryMessage, buf[:n]); err != nil {
					log.Printf("WebSocket write error: %v", err)
					return
				}
			}
		}
	}()

	// Goroutine 3: Ping to keep connection alive
	wg.Add(1)
	go func() {
		defer wg.Done()
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-done:
				return
			case <-ticker.C:
				if err := ws.WriteControl(websocket.PingMessage, []byte{}, time.Now().Add(10*time.Second)); err != nil {
					log.Printf("Ping error: %v", err)
					return
				}
			}
		}
	}()

	// Wait for all goroutines to finish
	wg.Wait()

	log.Printf("WebSocket closed for session %s", sessionID)
}
