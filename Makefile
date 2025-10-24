.PHONY: build test run clean dev help

# Default target
.DEFAULT_GOAL := help

# Build the server binary
build:
	@echo "Building server..."
	@mkdir -p bin
	@go build -o bin/shellcraft-server ./cmd/server
	@echo "✓ Binary built: bin/shellcraft-server"

# Run all tests
test:
	@echo "Running tests..."
	@go test ./... -v

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	@go test ./... -cover -coverprofile=coverage.out
	@go tool cover -html=coverage.out -o coverage.html
	@echo "✓ Coverage report: coverage.html"

# Run tests (short mode, skip integration tests)
test-short:
	@echo "Running unit tests..."
	@go test ./... -short

# Run tests with race detector
test-race:
	@echo "Running tests with race detector..."
	@go test ./... -race

# Run the server locally
run: build
	@echo "Starting server on port 8080..."
	@./bin/shellcraft-server

# Run in development mode (with live reload would require additional tools)
dev:
	@echo "Running in development mode..."
	@PORT=8080 SHELLCRAFT_IMAGE=alpine:latest go run ./cmd/server/main.go

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@rm -rf bin/
	@rm -f coverage.out coverage.html
	@echo "✓ Cleaned"

# Install dependencies
deps:
	@echo "Installing dependencies..."
	@go mod download
	@go mod tidy
	@echo "✓ Dependencies installed"

# Format code
fmt:
	@echo "Formatting code..."
	@go fmt ./...
	@echo "✓ Code formatted"

# Lint code (requires golangci-lint)
lint:
	@echo "Linting code..."
	@golangci-lint run || echo "Install golangci-lint: https://golangci-lint.run/usage/install/"

# Check if Docker is running
docker-check:
	@docker info > /dev/null 2>&1 || (echo "❌ Docker is not running" && exit 1)
	@echo "✓ Docker is running"

# Pull default image
docker-pull:
	@echo "Pulling alpine:latest..."
	@docker pull alpine:latest
	@echo "✓ Image pulled"

# Run integration test with real Docker
test-integration: docker-check docker-pull
	@echo "Running integration tests..."
	@go test ./... -v

# Show help
help:
	@echo "ShellCraft Server - Makefile commands:"
	@echo ""
	@echo "  make build            - Build the server binary"
	@echo "  make test             - Run all tests"
	@echo "  make test-coverage    - Run tests with coverage report"
	@echo "  make test-short       - Run unit tests only (skip integration)"
	@echo "  make test-race        - Run tests with race detector"
	@echo "  make run              - Build and run the server"
	@echo "  make dev              - Run in development mode"
	@echo "  make clean            - Remove build artifacts"
	@echo "  make deps             - Install Go dependencies"
	@echo "  make fmt              - Format code"
	@echo "  make lint             - Lint code (requires golangci-lint)"
	@echo "  make docker-check     - Verify Docker is running"
	@echo "  make docker-pull      - Pull default Alpine image"
	@echo "  make test-integration - Run integration tests with Docker"
	@echo "  make help             - Show this help message"
	@echo ""
	@echo "Quick start:"
	@echo "  1. make deps          # Install dependencies"
	@echo "  2. make test          # Run tests"
	@echo "  3. make build         # Build binary"
	@echo "  4. make run           # Start server"
	@echo ""
