package docker

import (
	"context"
	"fmt"
	"io"
	"sync"

	"github.com/docker/docker/api/types/container"
)

// MockClient is a fake Docker client for testing
type MockClient struct {
	mu         sync.RWMutex
	images     map[string]bool
	containers map[string]*mockContainer
	nextID     int
}

type mockContainer struct {
	ID      string
	Image   string
	Running bool
}

// NewMockClient creates a new mock Docker client
func NewMockClient() *MockClient {
	return &MockClient{
		images:     make(map[string]bool),
		containers: make(map[string]*mockContainer),
	}
}

// AddImage adds an image to the mock registry
func (m *MockClient) AddImage(name string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.images[name] = true
}

// ListImages returns a list of available image names
func (m *MockClient) ListImages(ctx context.Context) ([]string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	var imageNames []string
	for name := range m.images {
		imageNames = append(imageNames, name)
	}
	return imageNames, nil
}

// ListContainers returns container IDs (mock ignores labels)
func (m *MockClient) ListContainers(ctx context.Context, labels map[string]string) ([]string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	var containerIDs []string
	for id := range m.containers {
		containerIDs = append(containerIDs, id)
	}
	return containerIDs, nil
}

// CreateContainer creates a new mock container
func (m *MockClient) CreateContainer(ctx context.Context, imageName string, config *container.Config) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Auto-add image if not present (simulating pull)
	m.images[imageName] = true

	m.nextID++
	containerID := fmt.Sprintf("mock-%d", m.nextID)

	m.containers[containerID] = &mockContainer{
		ID:      containerID,
		Image:   imageName,
		Running: false,
	}

	return containerID, nil
}

// StartContainer starts a mock container
func (m *MockClient) StartContainer(ctx context.Context, containerID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	c, exists := m.containers[containerID]
	if !exists {
		return fmt.Errorf("container %s not found", containerID)
	}

	c.Running = true
	return nil
}

// StopContainer stops a mock container
func (m *MockClient) StopContainer(ctx context.Context, containerID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	c, exists := m.containers[containerID]
	if !exists {
		return fmt.Errorf("container %s not found", containerID)
	}

	c.Running = false
	return nil
}

// RemoveContainer removes a mock container
func (m *MockClient) RemoveContainer(ctx context.Context, containerID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.containers[containerID]; !exists {
		return fmt.Errorf("container %s not found", containerID)
	}

	delete(m.containers, containerID)
	return nil
}

// Close closes the mock client (no-op)
func (m *MockClient) Close() error {
	return nil
}

// AttachContainer returns a mock attachment (pipes for I/O)
func (m *MockClient) AttachContainer(ctx context.Context, containerID string) (*AttachResult, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if _, exists := m.containers[containerID]; !exists {
		return nil, fmt.Errorf("container %s not found", containerID)
	}

	// Create in-memory pipes for testing
	pr, pw := io.Pipe()

	resize := func(height, width uint) error {
		// Mock resize - just log it
		return nil
	}

	return &AttachResult{
		Reader: pr,
		Writer: pw,
		Resize: resize,
	}, nil
}

// GetContainer returns a container for testing assertions
func (m *MockClient) GetContainer(containerID string) (*mockContainer, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	c, exists := m.containers[containerID]
	return c, exists
}
