package docker

import (
	"context"
	"testing"
)

func TestMockDockerClient_ListImages(t *testing.T) {
	mock := NewMockClient()
	mock.AddImage("alpine:latest")
	mock.AddImage("busybox:latest")

	ctx := context.Background()
	images, err := mock.ListImages(ctx)
	if err != nil {
		t.Fatalf("ListImages failed: %v", err)
	}

	if len(images) != 2 {
		t.Errorf("expected 2 images, got %d", len(images))
	}
}

func TestMockDockerClient_CreateContainer(t *testing.T) {
	mock := NewMockClient()
	ctx := context.Background()

	containerID, err := mock.CreateContainer(ctx, "alpine:latest", nil)
	if err != nil {
		t.Fatalf("CreateContainer failed: %v", err)
	}

	if containerID == "" {
		t.Error("expected non-empty container ID")
	}

	// Verify container exists
	c, exists := mock.GetContainer(containerID)
	if !exists {
		t.Error("container should exist after creation")
	}

	if c.Image != "alpine:latest" {
		t.Errorf("expected image 'alpine:latest', got %s", c.Image)
	}

	if c.Running {
		t.Error("container should not be running after creation")
	}
}

func TestMockDockerClient_StartContainer(t *testing.T) {
	mock := NewMockClient()
	ctx := context.Background()

	containerID, _ := mock.CreateContainer(ctx, "alpine:latest", nil)

	err := mock.StartContainer(ctx, containerID)
	if err != nil {
		t.Fatalf("StartContainer failed: %v", err)
	}

	c, _ := mock.GetContainer(containerID)
	if !c.Running {
		t.Error("container should be running after start")
	}
}

func TestMockDockerClient_StopContainer(t *testing.T) {
	mock := NewMockClient()
	ctx := context.Background()

	containerID, _ := mock.CreateContainer(ctx, "alpine:latest", nil)
	mock.StartContainer(ctx, containerID)

	err := mock.StopContainer(ctx, containerID)
	if err != nil {
		t.Fatalf("StopContainer failed: %v", err)
	}

	c, _ := mock.GetContainer(containerID)
	if c.Running {
		t.Error("container should not be running after stop")
	}
}

func TestMockDockerClient_RemoveContainer(t *testing.T) {
	mock := NewMockClient()
	ctx := context.Background()

	containerID, _ := mock.CreateContainer(ctx, "alpine:latest", nil)

	err := mock.RemoveContainer(ctx, containerID)
	if err != nil {
		t.Fatalf("RemoveContainer failed: %v", err)
	}

	_, exists := mock.GetContainer(containerID)
	if exists {
		t.Error("container should not exist after removal")
	}
}

func TestMockDockerClient_FullLifecycle(t *testing.T) {
	mock := NewMockClient()
	ctx := context.Background()

	// Create
	containerID, err := mock.CreateContainer(ctx, "alpine:latest", nil)
	if err != nil {
		t.Fatalf("CreateContainer failed: %v", err)
	}

	// Start
	if err := mock.StartContainer(ctx, containerID); err != nil {
		t.Fatalf("StartContainer failed: %v", err)
	}

	c, _ := mock.GetContainer(containerID)
	if !c.Running {
		t.Error("container should be running")
	}

	// Stop
	if err := mock.StopContainer(ctx, containerID); err != nil {
		t.Fatalf("StopContainer failed: %v", err)
	}

	c, _ = mock.GetContainer(containerID)
	if c.Running {
		t.Error("container should be stopped")
	}

	// Remove
	if err := mock.RemoveContainer(ctx, containerID); err != nil {
		t.Fatalf("RemoveContainer failed: %v", err)
	}

	_, exists := mock.GetContainer(containerID)
	if exists {
		t.Error("container should be removed")
	}
}
