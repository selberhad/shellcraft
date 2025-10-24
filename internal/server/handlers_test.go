package server

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/shellcraft/server/internal/docker"
)

func TestCreateSession(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	req := httptest.NewRequest(http.MethodPost, "/session", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	var response map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &response); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	sessionID, exists := response["session_id"]
	if !exists || sessionID == "" {
		t.Error("expected session_id in response")
	}

	containerID, exists := response["container_id"]
	if !exists || containerID == "" {
		t.Error("expected container_id in response")
	}
}

func TestCreateSessionWithCustomImage(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	body := map[string]string{"image": "busybox:latest"}
	bodyBytes, _ := json.Marshal(body)

	req := httptest.NewRequest(http.MethodPost, "/session", bytes.NewReader(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	var response map[string]string
	json.Unmarshal(rec.Body.Bytes(), &response)

	// Verify container was created
	containerID := response["container_id"]
	container, exists := mockDocker.GetContainer(containerID)
	if !exists {
		t.Fatal("container should exist")
	}

	if container.Image != "busybox:latest" {
		t.Errorf("expected image 'busybox:latest', got %s", container.Image)
	}
}

func TestDeleteSession(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	// Create a session first
	sessionID, containerID := createTestSession(t, srv)

	// Delete the session
	req := httptest.NewRequest(http.MethodDelete, "/session/"+sessionID, nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	// Verify container was removed
	_, exists := mockDocker.GetContainer(containerID)
	if exists {
		t.Error("container should be removed")
	}
}

func TestDeleteSession_NotFound(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	req := httptest.NewRequest(http.MethodDelete, "/session/nonexistent", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, rec.Code)
	}
}

func TestGetSessionStatus(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	// Create a session
	sessionID, containerID := createTestSession(t, srv)

	// Start the container
	mockDocker.StartContainer(context.Background(), containerID)

	// Get status
	req := httptest.NewRequest(http.MethodGet, "/session/"+sessionID+"/status", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	var response map[string]string
	json.Unmarshal(rec.Body.Bytes(), &response)

	if response["status"] != "running" {
		t.Errorf("expected status 'running', got %s", response["status"])
	}
}

func TestGetSessionStatus_NotFound(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	req := httptest.NewRequest(http.MethodGet, "/session/nonexistent/status", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, rec.Code)
	}
}

// Helper function to create a test session
func createTestSession(t *testing.T, srv *Server) (string, string) {
	req := httptest.NewRequest(http.MethodPost, "/session", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	var response map[string]string
	json.Unmarshal(rec.Body.Bytes(), &response)

	return response["session_id"], response["container_id"]
}
