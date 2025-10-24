package server

import (
	"encoding/json"
	"net/http"
	"runtime"
)

// ServerMetrics represents current server resource usage
type ServerMetrics struct {
	ActiveSessions   int    `json:"active_sessions"`
	MaxSessions      int    `json:"max_sessions"`
	CapacityPercent  int    `json:"capacity_percent"`
	MemoryAllocMB    uint64 `json:"memory_alloc_mb"`
	MemorySysMB      uint64 `json:"memory_sys_mb"`
	NumGoroutines    int    `json:"num_goroutines"`
	Status           string `json:"status"`
}

// handleMetrics returns server metrics
func (s *Server) handleMetrics(w http.ResponseWriter, r *http.Request) {
	sessions := s.sessionManager.ListSessions()
	activeCount := len(sessions)
	capacityPercent := (activeCount * 100) / MaxConcurrentSessions

	// Get memory stats
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	status := "healthy"
	if capacityPercent >= 90 {
		status = "critical"
	} else if capacityPercent >= 75 {
		status = "warning"
	}

	metrics := ServerMetrics{
		ActiveSessions:   activeCount,
		MaxSessions:      MaxConcurrentSessions,
		CapacityPercent:  capacityPercent,
		MemoryAllocMB:    m.Alloc / 1024 / 1024,
		MemorySysMB:      m.Sys / 1024 / 1024,
		NumGoroutines:    runtime.NumGoroutine(),
		Status:           status,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(metrics)
}
