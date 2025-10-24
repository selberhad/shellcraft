# ShellCraft Orchestration Server — TDD Implementation Plan

## 1. Summary

The ShellCraft orchestration server is responsible for managing player sessions by provisioning isolated Docker containers, connecting them to a web-based terminal, and proxying I/O between the player and the in-container shell (Perl or Rust-based). It exposes REST and WebSocket endpoints for session management and terminal streaming.

The focus of this TDD plan is correctness, isolation, and robustness — ensuring that container lifecycle operations, player sessions, and WebSocket streams are all tested before implementation.

---

## 2. Architecture Overview

**Frontend**
- TypeScript + xterm.js terminal interface
- Connects via WebSocket to the Go backend

**Backend**
- Go (1.23+)
- chi router for REST API
- gorilla/websocket for interactive sessions
- Docker SDK for container management
- Redis (optional) for persistent session store
- Structured logging via zap or zerolog

**Game Sandbox**
- Each player gets a dedicated Docker container
- Image: prebuilt shell environment with limited commands
- No external networking; local-only communication with orchestrator
- Player state stored in `/home/spellbook.dat`

---

## 3. Core Responsibilities

- Launch and tear down Docker containers per player
- Maintain in-memory session tracking
- Bridge interactive terminal I/O via WebSocket
- Enforce timeouts and cleanup of idle sessions
- Serve lightweight frontend for web terminal

---

## 4. TDD Implementation Plan

### Phase 1 — Core Project Setup

1.a Write failing tests:
- Verify server starts and responds to `/healthz` with 200 OK.
- Use httptest to issue requests to in-memory router.

1.b Implement chi-based HTTP server with a `/healthz` handler returning `"ok"`.

---

### Phase 2 — Docker Integration Layer

2.a Write failing tests for `DockerClient` interface:
- `ListImages()` returns a slice of image names.
- `CreateContainer(image)` returns container ID.
- `StartContainer(id)` marks container as running.
- `StopContainer(id)` gracefully halts container.
- `RemoveContainer(id)` deletes container.

Use a fake Docker backend for unit testing.

2.b Implement `dockerclient.go` using official Docker SDK:
- Establish client with `client.NewClientWithOpts()`.
- Implement methods to make tests pass against mock.
- Later add integration tests against a real Docker daemon.

---

### Phase 3 — Session Management

3.a Write failing tests for `SessionManager`:
- `NewSession()` returns unique session ID.
- `AttachContainer(sessionID, containerID)` associates session with container.
- `DestroySession(sessionID)` removes and stops container.
- `ListSessions()` returns all active sessions.

3.b Implement in-memory session manager:
- Use a map protected by `sync.RWMutex`.
- Store container IDs and timestamps.
- Ensure thread-safe creation and deletion.

---

### Phase 4 — Container Lifecycle API

4.a Write failing tests for REST routes:
- `POST /session` → returns `{ "session_id": "abc123" }`.
- `DELETE /session/{id}` → stops and removes the container.
- `GET /session/{id}/status` → returns `"running"`, `"stopped"`, or `"missing"`.

4.b Implement HTTP handlers using chi:
- Integrate with `DockerClient` and `SessionManager`.
- Return appropriate HTTP codes and JSON payloads.

---

### Phase 5 — WebSocket Shell Bridge

5.a Write failing tests using websocket dialer:
- Connect to `/session/{id}/ws`.
- Send `"ls\n"`.
- Expect mock PTY output `"spellbook.dat"`.

Use a mock PTY that echoes simulated shell output for tests.

5.b Implement `WebSocketBridge`:
- Create PTY inside container via `ContainerAttach`.
- Forward incoming WebSocket messages to container stdin.
- Stream stdout/stderr from container back to WebSocket.
- Ensure clean shutdown on disconnect.

---

### Phase 6 — Frontend Bootstrap Endpoint

6.a Write failing test:
- `GET /session/{id}/connect` should return HTML containing the correct WebSocket URL.

6.b Implement HTML template renderer:
- Inject `{session_id}` and `{ws_url}` placeholders.
- Serve a minimal xterm.js bootstrap page.

---

### Phase 7 — Resource Cleanup and Timeouts

7.a Write failing tests:
- Idle sessions are auto-cleaned after 15 minutes.
- Zombie containers are reaped on server restart.

7.b Implement cleanup goroutine:
- Periodically check last activity timestamps.
- Stop and remove containers past timeout.
- Maintain metrics for cleanup counts.

---

### Phase 8 — Persistent Session Store (Optional)

8.a Write failing tests for Redis-backed store:
- Session data survives server restart.
- Session lookup via key returns valid container ID.

8.b Implement Redis persistence layer behind `SessionStore` interface:
- Use `go-redis/v9` client.
- Serialize session structs as JSON.

---

### Phase 9 — Integration & E2E Tests

9.a Write end-to-end tests:
- Create session → connect via WebSocket → execute command → receive output → destroy session.
- Ensure teardown cleans all containers.

9.b Refactor for testability:
- Add dependency injection for Docker client and session store.
- Use `docker compose up -d` for integration test harness.

---

### Phase 10 — Deployment and Hardening

10.a Write tests for configuration:
- Environment variables load correctly (`PORT`, `IMAGE_NAME`, etc.).
- Invalid configs return meaningful errors.

10.b Implement final hardening:
- Add request logging middleware.
- Add panic recovery.
- Integrate Prometheus metrics.
- Graceful shutdown on SIGINT/SIGTERM.

---

## 5. Deliverables by Phase

| Phase | Deliverable | Tests |
|--------|--------------|-------|
| 1 | Running HTTP server | Health check |
| 2 | Docker client wrapper | Mock Docker integration |
| 3 | Session manager | Thread safety, cleanup |
| 4 | Lifecycle API | REST endpoints |
| 5 | WebSocket bridge | Bidirectional I/O |
| 6 | HTML bootstrap | Template rendering |
| 7 | Cleanup system | Timeout handling |
| 8 | Redis persistence | Restart survival |
| 9 | E2E coverage | Full session lifecycle |
| 10 | Hardened release | Config + metrics |

---

## 6. Future Enhancements

- Authentication (e.g., JWT or anonymous token)
- Multi-instance orchestrator scaling via Redis pub/sub
- File upload/download integration
- Container pool prewarming for instant startup
- Admin dashboard for live session monitoring