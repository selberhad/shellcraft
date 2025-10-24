# ShellCraft Server - Quick Start Guide

Get the server running in 3 minutes.

---

## Prerequisites

- Docker running locally
- Go 1.21+ installed

**Verify Docker:**
```bash
docker info
# Should show Docker version and system info
```

---

## 1. Install Dependencies

```bash
make deps
```

Or manually:
```bash
go mod download
go mod tidy
```

---

## 2. Run Tests

```bash
make test-short
```

Expected output:
```
ok  	github.com/shellcraft/server/internal/docker	0.2s
ok  	github.com/shellcraft/server/internal/server	0.5s
ok  	github.com/shellcraft/server/internal/session	0.3s
```

**35 tests should pass!**

---

## 3. Build the Server

```bash
make build
```

Creates binary at: `bin/shellcraft-server`

---

## 4. Start the Server

```bash
make run
```

Or directly:
```bash
./bin/shellcraft-server
```

Expected output:
```
2025/10/24 17:15:00 Started cleanup manager (interval: 5m0s, timeout: 15m0s)
2025/10/24 17:15:00 Starting ShellCraft server on port 4242
```

Server is now running at `http://localhost:4242`

---

## 5. Test It!

### a) Health Check
```bash
curl http://localhost:4242/healthz
# Response: ok
```

### b) Create Session
```bash
curl -X POST http://localhost:4242/session
```

Response:
```json
{
  "session_id": "3b1f8e4a-7c2d-4f9e-8a1b-2d3e4f5a6b7c",
  "container_id": "abc123def456..."
}
```

### c) Open Terminal

Copy the `session_id` from above and open in browser:
```
http://localhost:4242/session/{session_id}/connect
```

You should see a terminal interface! Type commands like:
- `ls`
- `pwd`
- `echo "Hello ShellCraft"`
- `cat /etc/os-release`

### d) Check Status
```bash
curl http://localhost:4242/session/{session_id}/status
```

Response:
```json
{
  "status": "running"
}
```

### e) Cleanup
```bash
curl -X DELETE http://localhost:4242/session/{session_id}
```

Response:
```json
{
  "status": "deleted"
}
```

---

## Configuration

Set environment variables before starting:

```bash
# Custom port
PORT=3000 ./bin/shellcraft-server

# Custom container image
SHELLCRAFT_IMAGE=busybox:latest ./bin/shellcraft-server

# Both
PORT=3000 SHELLCRAFT_IMAGE=busybox:latest ./bin/shellcraft-server
```

---

## Development Mode

Run without building:

```bash
make dev
```

Or:
```bash
go run ./cmd/server/main.go
```

---

## Troubleshooting

### Docker not found
```
Error: Cannot connect to the Docker daemon
```

**Fix**: Start Docker Desktop or `dockerd`

### Port already in use
```
Error: bind: address already in use
```

**Fix**: Change port
```bash
PORT=3001 ./bin/shellcraft-server
```

### Tests failing
```
Error: container creation failed
```

**Fix**: Pull Alpine image first
```bash
docker pull alpine:latest
```

---

## Stop the Server

Press `Ctrl+C` in the terminal running the server.

Expected output:
```
^C
2025/10/24 17:20:00 Shutting down server...
2025/10/24 17:20:00 Stopped cleanup manager
2025/10/24 17:20:00 Server stopped
```

---

## What's Next?

- Read `README.md` for full API documentation
- Check `IMPLEMENTATION.md` for technical details
- Review `SERVER.md` for TDD implementation plan
- Explore `GAMESHELL.md` for game design

---

## Full Workflow Example

```bash
# 1. Clone/navigate to project
cd shellcraft

# 2. Install dependencies
make deps

# 3. Run tests
make test-short

# 4. Build
make build

# 5. Start server
./bin/shellcraft-server &

# 6. Create session
SESSION=$(curl -s -X POST http://localhost:4242/session | jq -r .session_id)
echo "Session ID: $SESSION"

# 7. Open in browser
open "http://localhost:4242/session/$SESSION/connect"

# 8. Or connect via WebSocket (using wscat)
# npm install -g wscat
# wscat -c "ws://localhost:4242/session/$SESSION/ws"

# 9. Check status
curl http://localhost:4242/session/$SESSION/status

# 10. Cleanup
curl -X DELETE http://localhost:4242/session/$SESSION

# 11. Stop server
pkill shellcraft-server
```

---

## Next Steps

Ready to dive deeper?

1. **Customize the container**
   - Edit `SHELLCRAFT_IMAGE` to use your own Docker image
   - Pre-install game files or tools

2. **Build the game shell**
   - See `GAMESHELL.md` for game mechanics
   - Implement XP system, command unlocks, etc.

3. **Add persistence**
   - Implement Phase 8: Redis session store
   - Survive server restarts

4. **Production deploy**
   - Add authentication
   - Set up reverse proxy (nginx)
   - Configure SSL/TLS
   - Add monitoring (Prometheus)

---

**You're ready to craft some shells! 🚀**
