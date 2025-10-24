# ShellCraft Server

ShellCraft orchestration server manages player sessions by provisioning isolated Docker containers, connecting them to a web-based terminal, and proxying I/O between the player and the in-container shell.

Built with **TDD-first methodology** following the principles outlined in `LEXICON.md`.

---

## Architecture

### Components

- **Frontend**: Web-based terminal using xterm.js
- **Backend**: Go 1.21+ server with:
  - `chi` router for REST API
  - `gorilla/websocket` for interactive terminal sessions
  - Docker SDK for container management
  - Thread-safe in-memory session store
  - Automatic cleanup of idle sessions

### Container Sandbox

Each player gets a dedicated Docker container:
- Base image: Alpine/BusyBox (configurable via `SHELLCRAFT_IMAGE` env var)
- No external networking
- Isolated environment per session
- TTY attached for interactive shell

---

## Features Implemented (Phases 1-7)

### ✅ Phase 1: Core Project Setup
- HTTP server with chi router
- Health check endpoint: `GET /healthz`
- Graceful shutdown on SIGINT/SIGTERM

### ✅ Phase 2: Docker Integration Layer
- `DockerClient` interface with mock implementation for testing
- Container lifecycle operations: create, start, stop, remove
- PTY attachment support for interactive I/O

### ✅ Phase 3: Session Management
- Thread-safe in-memory session manager
- Session lifecycle: create, attach container, destroy
- Activity tracking for idle detection
- Concurrent session support

### ✅ Phase 4: REST API
- `POST /session` - Create new session and container
  - Optional body: `{"image": "alpine:latest"}`
  - Returns: `{"session_id": "...", "container_id": "..."}`
- `DELETE /session/{id}` - Destroy session and remove container
- `GET /session/{id}/status` - Get container status (running/stopped/missing)

### ✅ Phase 5: WebSocket Terminal Bridge
- `GET /session/{id}/ws` - Interactive WebSocket terminal
- Bidirectional I/O streaming: browser ↔ container
- Automatic activity tracking
- Connection keep-alive with ping/pong
- Graceful disconnection handling

### ✅ Phase 6: Web Terminal Interface
- `GET /session/{id}/connect` - HTML page with embedded xterm.js
- Retro terminal styling with green-on-black theme
- Auto-reconnection on disconnect (max 5 attempts)
- Real-time connection status indicator
- Responsive design

### ✅ Phase 7: Cleanup System
- Automatic idle session cleanup (default: 15 min timeout)
- Configurable cleanup interval
- Metrics: track cleaned session count
- Container resource cleanup

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/healthz` | Health check |
| `POST` | `/session` | Create new session |
| `DELETE` | `/session/{id}` | Destroy session |
| `GET` | `/session/{id}/status` | Get session status |
| `GET` | `/session/{id}/ws` | WebSocket terminal |
| `GET` | `/session/{id}/connect` | Web terminal UI |

---

## Quick Start

### Prerequisites

- Go 1.21+
- Docker daemon running
- Alpine or BusyBox image (pulled automatically)

### Build

```bash
go build -o bin/shellcraft-server ./cmd/server
```

### Run

```bash
# Default configuration
./bin/shellcraft-server

# Custom port
PORT=3000 ./bin/shellcraft-server

# Custom container image
SHELLCRAFT_IMAGE=busybox:latest ./bin/shellcraft-server
```

Server starts on port `8080` by default.

### Test

```bash
# Run all tests
go test ./...

# Run with coverage
go test ./... -cover

# Run specific package
go test ./internal/server/... -v

# Skip integration tests
go test ./... -short
```

**Test Coverage**: 35 tests passing across all components.

---

## Usage Example

### 1. Create a session

```bash
curl -X POST http://localhost:8080/session
```

Response:
```json
{
  "session_id": "3b1f8e4a-...",
  "container_id": "abc123..."
}
```

### 2. Open web terminal

Visit: `http://localhost:8080/session/3b1f8e4a-.../connect`

Or connect programmatically via WebSocket:
```javascript
const ws = new WebSocket('ws://localhost:8080/session/3b1f8e4a-.../ws');
ws.onmessage = (event) => console.log(event.data);
ws.send('ls\n');
```

### 3. Check status

```bash
curl http://localhost:8080/session/3b1f8e4a-.../status
```

Response:
```json
{
  "status": "running"
}
```

### 4. Cleanup

```bash
curl -X DELETE http://localhost:8080/session/3b1f8e4a-...
```

Or wait 15 minutes for automatic cleanup.

---

## Project Structure

```
shellcraft/
├── cmd/
│   └── server/
│       └── main.go              # Entry point
├── internal/
│   ├── docker/
│   │   ├── client.go            # Docker client interface
│   │   ├── client_test.go       # Docker tests
│   │   └── mock.go              # Mock Docker client
│   ├── server/
│   │   ├── server.go            # HTTP server
│   │   ├── server_test.go       # Server tests
│   │   ├── handlers_test.go     # API endpoint tests
│   │   ├── websocket.go         # WebSocket bridge
│   │   ├── websocket_test.go    # WebSocket tests
│   │   ├── frontend.go          # Web terminal UI
│   │   ├── frontend_test.go     # Frontend tests
│   │   ├── cleanup.go           # Cleanup manager
│   │   └── cleanup_test.go      # Cleanup tests
│   └── session/
│       ├── manager.go           # Session manager
│       └── manager_test.go      # Session tests
├── go.mod
├── go.sum
├── LEXICON.md                   # Guiding principles
├── SERVER.md                    # TDD implementation plan
├── GAMESHELL.md                 # Game specification
└── README.md                    # This file
```

---

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `PORT` | `8080` | HTTP server port |
| `SHELLCRAFT_IMAGE` | `alpine:latest` | Default container image |

---

## Testing Philosophy

Following **TDD principles from LEXICON.md**:

1. **Write failing test first**
2. **Implement minimal code to pass**
3. **Refactor for clarity**

### Test Categories

- **Unit tests**: Isolated component testing with mocks
- **Integration tests**: Real Docker daemon interaction (skipped in `-short` mode)
- **Concurrent tests**: Thread safety and race condition detection

Run with race detector:
```bash
go test ./... -race
```

---

## Future Enhancements (Not Yet Implemented)

### Phase 8: Persistent Session Store (Optional)
- Redis/MongoDB backend for session persistence
- Survive server restarts
- Multi-instance orchestrator scaling

### Phase 9: E2E Tests
- Full session lifecycle integration tests
- Docker Compose test harness
- Container teardown verification

### Phase 10: Production Hardening
- Authentication (JWT/anonymous tokens)
- Request rate limiting
- Prometheus metrics
- Admin dashboard
- Container pool prewarming
- File upload/download

---

## Contributing

This project follows the **dialectical method** (thesis → antithesis → synthesis):

1. Identify problem (thesis)
2. Propose solution (antithesis)
3. Implement and test (synthesis)

All code must:
- Have tests written *first*
- Follow "Context is king" - state determines behavior
- Be inspectable - no black boxes
- Use domain language over implementation details

---

## License

MIT (or your preferred license)

---

## Acknowledgments

Built following TDD best practices and the philosophical principles outlined in `LEXICON.md`:
- "Artifacts are disposable, clarity is durable"
- "Docs → Tests → Implementation → Learnings"
- "Infrastructure compounds"

---

**Server is ready for Phase 8+ implementation or production deployment!**
