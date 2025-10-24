package server

import (
	"context"
	"log"
	"sync"
	"time"
)

// CleanupManager handles periodic cleanup of idle sessions
type CleanupManager struct {
	server       *Server
	ticker       *time.Ticker
	done         chan struct{}
	wg           sync.WaitGroup
	idleTimeout  time.Duration
	cleanupCount int
	mu           sync.Mutex
}

// StartCleanup starts the automatic cleanup goroutine with default 15-minute idle timeout
func (s *Server) StartCleanup(interval time.Duration) {
	s.StartCleanupWithTimeout(interval, 15*time.Minute)
}

// StartCleanupWithTimeout starts the automatic cleanup goroutine with custom idle timeout
func (s *Server) StartCleanupWithTimeout(interval, idleTimeout time.Duration) {
	if s.cleanupManager != nil {
		log.Println("Cleanup already running")
		return
	}

	s.cleanupManager = &CleanupManager{
		server:      s,
		ticker:      time.NewTicker(interval),
		done:        make(chan struct{}),
		idleTimeout: idleTimeout,
	}

	s.cleanupManager.wg.Add(1)
	go s.cleanupManager.run()

	log.Printf("Started cleanup manager (interval: %v, timeout: %v)", interval, idleTimeout)
}

// StopCleanup stops the cleanup goroutine
func (s *Server) StopCleanup() {
	if s.cleanupManager == nil {
		return
	}

	close(s.cleanupManager.done)
	s.cleanupManager.wg.Wait()
	s.cleanupManager = nil

	log.Println("Stopped cleanup manager")
}

// run is the main cleanup loop
func (cm *CleanupManager) run() {
	defer cm.wg.Done()

	for {
		select {
		case <-cm.done:
			cm.ticker.Stop()
			return
		case <-cm.ticker.C:
			count := cm.server.CleanupIdleSessions(cm.idleTimeout)
			if count > 0 {
				log.Printf("Cleaned up %d idle sessions", count)
			}
		}
	}
}

// CleanupIdleSessions removes sessions that have been idle for longer than the timeout
// Returns the number of sessions cleaned up
func (s *Server) CleanupIdleSessions(idleTimeout time.Duration) int {
	ctx := context.Background()
	idleSessions := s.sessionManager.GetIdleSessions(idleTimeout)

	count := 0
	for _, session := range idleSessions {
		log.Printf("Cleaning up idle session %s (idle for %v)", session.ID, time.Since(session.LastActivity))

		// Destroy session and get container ID
		containerID, err := s.sessionManager.DestroySession(session.ID)
		if err != nil {
			log.Printf("Failed to destroy session %s: %v", session.ID, err)
			continue
		}

		// Stop and remove container
		if containerID != "" {
			if err := s.dockerClient.StopContainer(ctx, containerID); err != nil {
				log.Printf("Failed to stop container %s: %v", containerID, err)
			}
			if err := s.dockerClient.RemoveContainer(ctx, containerID); err != nil {
				log.Printf("Failed to remove container %s: %v", containerID, err)
			}
		}

		count++
	}

	return count
}

// CleanupZombieContainers removes containers that exist in Docker but not in session manager
// This can happen after a server restart
func (s *Server) CleanupZombieContainers() error {
	// TODO: Implement by listing all containers with a specific label
	// and removing those not in the session manager
	log.Println("Zombie container cleanup not yet implemented")
	return nil
}
