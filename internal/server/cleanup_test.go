package server

import (
	"testing"
	"time"

	"github.com/shellcraft/server/internal/docker"
)

func TestCleanupManager_StartStop(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	// Start cleanup
	srv.StartCleanup(100 * time.Millisecond)

	// Wait a bit
	time.Sleep(200 * time.Millisecond)

	// Stop cleanup
	srv.StopCleanup()

	// Should not panic or error
}

func TestCleanupManager_RemovesIdleSessions(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	// Create a session
	sessionID, containerID := createTestSession(t, srv)

	// Manually set the session to be idle (old timestamp)
	srv.sessionManager.UpdateActivity(sessionID)
	time.Sleep(10 * time.Millisecond)

	// Manipulate the session timestamp to be old
	if _, exists := srv.sessionManager.GetSession(sessionID); exists {
		// Manually set old timestamp
		srv.sessionManager.DestroySession(sessionID)
		newSessionID := srv.sessionManager.NewSession()
		srv.sessionManager.AttachContainer(newSessionID, containerID)

		// Make it old
		srv.sessionManager.SetLastActivity(newSessionID, time.Now().Add(-20*time.Minute))

		// Run cleanup with short idle timeout
		srv.CleanupIdleSessions(1 * time.Minute)

		// Session should be destroyed
		_, exists := srv.sessionManager.GetSession(newSessionID)
		if exists {
			t.Error("expected idle session to be cleaned up")
		}

		// Container should be removed
		_, containerExists := mockDocker.GetContainer(containerID)
		if containerExists {
			t.Error("expected container to be removed")
		}
	} else {
		t.Fatal("session should exist")
	}
}

func TestCleanupManager_PreservesActiveSessions(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	// Create a session
	sessionID, _ := createTestSession(t, srv)

	// Update activity to mark it as active
	srv.sessionManager.UpdateActivity(sessionID)

	// Run cleanup
	srv.CleanupIdleSessions(15 * time.Minute)

	// Session should still exist
	_, exists := srv.sessionManager.GetSession(sessionID)
	if !exists {
		t.Error("active session should not be cleaned up")
	}
}

func TestCleanupManager_AutomaticCleanup(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	// Create a session and make it idle
	sessionID, containerID := createTestSession(t, srv)

	// Make session old
	srv.sessionManager.SetLastActivity(sessionID, time.Now().Add(-20*time.Minute))

	// Start cleanup with short interval and timeout
	srv.StartCleanupWithTimeout(50*time.Millisecond, 1*time.Minute)

	// Wait for cleanup to run
	time.Sleep(150 * time.Millisecond)

	// Stop cleanup
	srv.StopCleanup()

	// Session should be cleaned up
	_, exists := srv.sessionManager.GetSession(sessionID)
	if exists {
		t.Error("expected automatic cleanup to remove idle session")
	}

	// Container should be removed
	_, containerExists := mockDocker.GetContainer(containerID)
	if containerExists {
		t.Error("expected container to be removed by automatic cleanup")
	}
}

func TestCleanupManager_CleanupMetrics(t *testing.T) {
	mockDocker := docker.NewMockClient()
	srv := NewWithDockerClient(mockDocker)

	// Create multiple sessions
	for i := 0; i < 5; i++ {
		sessionID, _ := createTestSession(t, srv)

		// Make 3 of them idle
		if i < 3 {
			srv.sessionManager.SetLastActivity(sessionID, time.Now().Add(-20*time.Minute))
		}
	}

	// Run cleanup
	count := srv.CleanupIdleSessions(15 * time.Minute)

	if count != 3 {
		t.Errorf("expected 3 sessions cleaned, got %d", count)
	}

	// Verify 2 sessions remain
	sessions := srv.sessionManager.ListSessions()
	if len(sessions) != 2 {
		t.Errorf("expected 2 sessions remaining, got %d", len(sessions))
	}
}
