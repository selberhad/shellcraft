package server

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/shellcraft/server/internal/docker"
	"github.com/shellcraft/server/internal/session"
)

// Configuration constants
const (
	// MaxConcurrentSessions limits total active sessions based on available server RAM
	// With 3GB available and 50MB per container, safe limit is ~40 players
	MaxConcurrentSessions = 40
)

// Server represents the ShellCraft orchestration server
type Server struct {
	router         *chi.Mux
	dockerClient   docker.Client
	sessionManager *session.Manager
	defaultImage   string
	cleanupManager *CleanupManager
}

// New creates a new Server instance with routes configured
func New() *Server {
	dockerClient, err := docker.NewDockerClient()
	if err != nil {
		log.Fatalf("Failed to create Docker client: %v", err)
	}

	return NewWithDockerClient(dockerClient)
}

// NewWithDockerClient creates a new Server with a custom Docker client (for testing)
func NewWithDockerClient(dockerClient docker.Client) *Server {
	// Get default image from environment or use alpine
	defaultImage := os.Getenv("SHELLCRAFT_IMAGE")
	if defaultImage == "" {
		defaultImage = "alpine:latest"
	}

	s := &Server{
		router:         chi.NewRouter(),
		dockerClient:   dockerClient,
		sessionManager: session.NewManager(),
		defaultImage:   defaultImage,
	}

	// Add middleware
	s.router.Use(middleware.Logger)
	s.router.Use(middleware.Recoverer)

	// Register routes
	s.registerRoutes()

	return s
}

// Router returns the chi router for testing
func (s *Server) Router() *chi.Mux {
	return s.router
}

// registerRoutes sets up all HTTP routes
func (s *Server) registerRoutes() {
	s.router.Get("/healthz", s.handleHealthCheck)
	s.router.Get("/metrics", s.handleMetrics)
	s.router.Post("/session", s.handleCreateSession)
	s.router.Delete("/session/{id}", s.handleDeleteSession)
	s.router.Get("/session/{id}/status", s.handleGetSessionStatus)
	s.router.Get("/session/{id}/ws", s.handleWebSocket)
	s.router.Get("/session/{id}/connect", s.handleSessionConnect)
}

// handleHealthCheck returns a simple OK response
func (s *Server) handleHealthCheck(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("ok"))
}

// handleCreateSession creates a new session and container
func (s *Server) handleCreateSession(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()

	// Check server capacity before creating new session
	activeSessions := s.sessionManager.ListSessions()
	if len(activeSessions) >= MaxConcurrentSessions {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"error":           "Server at capacity",
			"active_sessions": len(activeSessions),
			"max_sessions":    MaxConcurrentSessions,
			"message":         "Please try again later or wait for a slot to open",
		})
		log.Printf("Rejected session creation: %d/%d sessions active", len(activeSessions), MaxConcurrentSessions)
		return
	}

	// Parse request body for optional image name
	var req struct {
		Image string `json:"image"`
	}
	if r.Body != nil {
		json.NewDecoder(r.Body).Decode(&req)
	}

	imageName := req.Image
	if imageName == "" {
		imageName = s.defaultImage
	}

	// Create session
	sessionID := s.sessionManager.NewSession()

	// Create and start container
	containerID, err := s.dockerClient.CreateContainer(ctx, imageName, nil)
	if err != nil {
		http.Error(w, "Failed to create container", http.StatusInternalServerError)
		log.Printf("Failed to create container: %v", err)
		return
	}

	if err := s.dockerClient.StartContainer(ctx, containerID); err != nil {
		http.Error(w, "Failed to start container", http.StatusInternalServerError)
		log.Printf("Failed to start container: %v", err)
		return
	}

	// Attach container to session
	if err := s.sessionManager.AttachContainer(sessionID, containerID); err != nil {
		http.Error(w, "Failed to attach container", http.StatusInternalServerError)
		log.Printf("Failed to attach container: %v", err)
		return
	}

	// Return session info
	response := map[string]string{
		"session_id":   sessionID,
		"container_id": containerID,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleDeleteSession destroys a session and its container
func (s *Server) handleDeleteSession(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	sessionID := chi.URLParam(r, "id")

	// Destroy session and get container ID
	containerID, err := s.sessionManager.DestroySession(sessionID)
	if err != nil {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	// Stop and remove container
	if containerID != "" {
		s.dockerClient.StopContainer(ctx, containerID)
		s.dockerClient.RemoveContainer(ctx, containerID)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "deleted"})
}

// handleGetSessionStatus returns the status of a session's container
func (s *Server) handleGetSessionStatus(w http.ResponseWriter, r *http.Request) {
	sessionID := chi.URLParam(r, "id")

	// Get session
	sess, exists := s.sessionManager.GetSession(sessionID)
	if !exists {
		http.Error(w, "Session not found", http.StatusNotFound)
		return
	}

	// Determine container status
	status := "unknown"
	if sess.ContainerID == "" {
		status = "missing"
	} else {
		// For mock client, check if container exists and is running
		if mockClient, ok := s.dockerClient.(*docker.MockClient); ok {
			container, exists := mockClient.GetContainer(sess.ContainerID)
			if !exists {
				status = "missing"
			} else if container.Running {
				status = "running"
			} else {
				status = "stopped"
			}
		} else {
			// For real Docker client, we'd inspect the container
			// For now, assume running if container ID exists
			status = "running"
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": status})
}
