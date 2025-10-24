package docker

import (
	"context"
	"io"

	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/image"
	"github.com/docker/docker/client"
)

// AttachResult holds the I/O streams for container attachment
type AttachResult struct {
	Reader io.Reader
	Writer io.WriteCloser
	Resize func(height, width uint) error
}

// Client is an interface for Docker operations
type Client interface {
	ListImages(ctx context.Context) ([]string, error)
	CreateContainer(ctx context.Context, imageName string, config *container.Config) (string, error)
	StartContainer(ctx context.Context, containerID string) error
	StopContainer(ctx context.Context, containerID string) error
	RemoveContainer(ctx context.Context, containerID string) error
	AttachContainer(ctx context.Context, containerID string) (*AttachResult, error)
	Close() error
}

// DockerClient implements the Client interface using the official Docker SDK
type DockerClient struct {
	cli *client.Client
}

// NewDockerClient creates a new Docker client
func NewDockerClient() (*DockerClient, error) {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, err
	}
	return &DockerClient{cli: cli}, nil
}

// ListImages returns a list of available image names
func (d *DockerClient) ListImages(ctx context.Context) ([]string, error) {
	images, err := d.cli.ImageList(ctx, image.ListOptions{})
	if err != nil {
		return nil, err
	}

	var imageNames []string
	for _, img := range images {
		if len(img.RepoTags) > 0 {
			imageNames = append(imageNames, img.RepoTags...)
		}
	}
	return imageNames, nil
}

// CreateContainer creates a new container from an image
func (d *DockerClient) CreateContainer(ctx context.Context, imageName string, config *container.Config) (string, error) {
	// Pull image if not present
	reader, err := d.cli.ImagePull(ctx, imageName, image.PullOptions{})
	if err != nil {
		return "", err
	}
	defer reader.Close()
	// Consume the pull output
	io.Copy(io.Discard, reader)

	// Use provided config or create default
	if config == nil {
		config = &container.Config{
			Image: imageName,
			Tty:   true,
		}
	} else if config.Image == "" {
		config.Image = imageName
	}

	resp, err := d.cli.ContainerCreate(ctx, config, nil, nil, nil, "")
	if err != nil {
		return "", err
	}
	return resp.ID, nil
}

// StartContainer starts a container
func (d *DockerClient) StartContainer(ctx context.Context, containerID string) error {
	return d.cli.ContainerStart(ctx, containerID, container.StartOptions{})
}

// StopContainer gracefully stops a container
func (d *DockerClient) StopContainer(ctx context.Context, containerID string) error {
	timeout := 10
	return d.cli.ContainerStop(ctx, containerID, container.StopOptions{Timeout: &timeout})
}

// RemoveContainer deletes a container
func (d *DockerClient) RemoveContainer(ctx context.Context, containerID string) error {
	return d.cli.ContainerRemove(ctx, containerID, container.RemoveOptions{Force: true})
}

// AttachContainer attaches to a container's TTY for interactive I/O
func (d *DockerClient) AttachContainer(ctx context.Context, containerID string) (*AttachResult, error) {
	// Attach to container with stdin/stdout/stderr
	resp, err := d.cli.ContainerAttach(ctx, containerID, container.AttachOptions{
		Stream: true,
		Stdin:  true,
		Stdout: true,
		Stderr: true,
	})
	if err != nil {
		return nil, err
	}

	// Create resize function
	resize := func(height, width uint) error {
		return d.cli.ContainerResize(ctx, containerID, container.ResizeOptions{
			Height: height,
			Width:  width,
		})
	}

	return &AttachResult{
		Reader: resp.Reader,
		Writer: resp.Conn,
		Resize: resize,
	}, nil
}

// Close closes the Docker client connection
func (d *DockerClient) Close() error {
	return d.cli.Close()
}
