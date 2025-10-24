package server

import (
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/shellcraft/server/internal/docker"
)

func TestGetSessionConnect(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	// Create a session
	sessionID, _ := createTestSession(t, srv)

	// Request the connect page
	req := httptest.NewRequest("GET", "/session/"+sessionID+"/connect", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	if rec.Code != 200 {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	body := rec.Body.String()

	// Verify HTML structure
	if !strings.Contains(body, "<!DOCTYPE html>") {
		t.Error("expected HTML doctype")
	}

	if !strings.Contains(body, "xterm") {
		t.Error("expected xterm reference")
	}

	// Verify session ID is embedded
	if !strings.Contains(body, sessionID) {
		t.Error("expected session ID in HTML")
	}

	// Verify WebSocket URL
	if !strings.Contains(body, "/ws") {
		t.Error("expected WebSocket URL in HTML")
	}
}

func TestGetSessionConnect_NotFound(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	req := httptest.NewRequest("GET", "/session/nonexistent/connect", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	if rec.Code != 404 {
		t.Errorf("expected status 404, got %d", rec.Code)
	}
}

func TestGetSessionConnect_ContentType(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	sessionID, _ := createTestSession(t, srv)

	req := httptest.NewRequest("GET", "/session/"+sessionID+"/connect", nil)
	rec := httptest.NewRecorder()

	srv.Router().ServeHTTP(rec, req)

	contentType := rec.Header().Get("Content-Type")
	if !strings.Contains(contentType, "text/html") {
		t.Errorf("expected Content-Type text/html, got %s", contentType)
	}
}
