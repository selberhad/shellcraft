# ShellCraft Server

**A fantasy-themed UNIX shell RPG where players learn real commands through gameplay.**

ShellCraft is a complete multiplayer game server that provisions isolated Docker containers running a custom Perl-based RPG shell. Players level up by executing commands, fight file-based enemies, and unlock new UNIX tools as they progress.

Built with **TDD-first methodology** following principles from `LEXICON.md`.

---

## 🎮 Features

### Complete Game System
- **RPG Progression**: Level 0-20 with XP-based advancement
- **Command Unlocking**: Start with basic commands, unlock advanced tools as you level
- **Combat System**: Fight file-based enemies (rats in `/sewer`, daemons in `/crypt`)
- **Binary Savefiles**: Progress saved in `spellbook.dat` with magic bytes "SHC!"
- **Fantasy Theme**: Commands become "spells", arguments are "mana", pipes are "spell combinations"

### Server Infrastructure
- **Web Terminal**: Beautiful xterm.js interface with retro green aesthetic
- **WebSocket Bridge**: Real-time bidirectional I/O streaming
- **Docker Orchestration**: Isolated container per player with 50MB memory limits
- **Session Management**: Thread-safe in-memory tracking with activity monitoring
- **Auto-Cleanup**: Idle sessions removed after 15 minutes
- **Capacity Management**: Hard limit of 40 concurrent players (configurable)
- **Metrics Endpoint**: Real-time server health monitoring

### User Experience
- **One-Click Start**: Landing page with instant session creation
- **ASCII Art Welcome**: Full banner displayed immediately on connect
- **Live Stats**: Level, XP, unlocked commands visible via `status` command
- **Help System**: In-game guidance with `help` command
- **Graceful Shutdown**: Progress auto-saved on exit

---

## 🏗️ Architecture

### Components

**Frontend**
- TypeScript + xterm.js terminal interface
- WebSocket connection to backend
- Auto-reconnection with 5 retry attempts
- Responsive terminal sizing

**Backend (Go 1.21+)**
- `chi` router for REST API
- `gorilla/websocket` for terminal sessions
- Docker SDK for container management
- Thread-safe session manager
- Background cleanup goroutine

**Game Container (Alpine + Perl)**
- Perl 5.38 REPL game loop
- Pre-populated world with enemies and lore
- Command validation and unlock system
- Binary savefile I/O
- File-based combat mechanics

---

## 🚀 Quick Start

### Prerequisites

- Docker running locally
- Go 1.21+ installed
- ~3GB RAM available for containers

### Build and Run

```bash
# 1. Clone and navigate
cd shellcraft

# 2. Build the game Docker image
cd docker/game-image
docker build -t shellcraft/game:latest .
cd ../..

# 3. Build the server
make build

# 4. Start the server
./bin/shellcraft-server
```

Server starts on **http://localhost:4242**

### Quick Test

```bash
# Health check
curl http://localhost:4242/healthz

# View metrics
curl http://localhost:4242/metrics

# Or just visit in browser
open http://localhost:4242
```

---

## 🎯 Gameplay

### Starting Out

1. Visit **http://localhost:4242**
2. Click "Start New Game"
3. See the ShellCraft ASCII banner
4. Press Enter to begin

### Your First Commands

```bash
$> status
# View your level, XP, and unlocked commands

$> help
# Get gameplay instructions

$> cd /sewer
$> ls
# Find enemy rat files

$> rm rat_1.rat
# Fight a rat! Gain XP!
```

### Progression

**Level 0**: Basic commands (ls, cat, echo, rm, cd, pwd, whoami, mkdir, touch)
**Level 1**: ls flags (ls -l, ls -a)
**Level 2**: File operations (mv, cp)
**Level 6**: grep (text search)
**Level 12**: find (seek beyond sight)
**Level 13**: awk (patterned spellcraft)
**Level 14**: sed (transform incantations)
**Level 20**: perl -e (true arcane mastery!)

### Combat System

Enemies are files with HP measured in bytes:
- **Rats** in `/sewer`: 100-500 bytes (early game grinding)
- **Skeleton** in `/crypt`: 800 bytes (mid-game)
- **Daemon** in `/crypt`: 1200 bytes (challenging)

Damage formula: `20 * log2(level + 2)` bytes per attack

### World Locations

- `/home` - Your base, contains `spellbook.dat`
- `/sewer` - 5 rats for early leveling
- `/crypt` - Tougher enemies with more XP
- `/tower` - Riddles and puzzles (coming soon)
- `/etc/scrolls` - Lore and command hints

---

## 📚 API Reference

### REST Endpoints

| Method | Endpoint | Description | Response |
|--------|----------|-------------|----------|
| `GET` | `/` | Landing page with session creation | HTML |
| `GET` | `/healthz` | Health check | `ok` |
| `GET` | `/metrics` | Server metrics (JSON) | Capacity, memory, status |
| `POST` | `/session` | Create new game session | `{session_id, container_id}` |
| `DELETE` | `/session/{id}` | Destroy session | `{status: "deleted"}` |
| `GET` | `/session/{id}/status` | Container status | `{status: "running"}` |
| `GET` | `/session/{id}/connect` | Web terminal UI | HTML |
| `GET` | `/session/{id}/ws` | WebSocket terminal | WebSocket upgrade |

### Metrics Response

```json
{
  "active_sessions": 5,
  "max_sessions": 40,
  "capacity_percent": 12,
  "memory_alloc_mb": 45,
  "memory_sys_mb": 78,
  "num_goroutines": 23,
  "status": "healthy"
}
```

Status levels: `healthy` (<75%), `warning` (75-89%), `critical` (≥90%)

---

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `4242` | HTTP server port |
| `SHELLCRAFT_IMAGE` | `shellcraft/game:latest` | Docker image for game containers |

### Server Limits

Edit `internal/server/server.go`:

```go
const MaxConcurrentSessions = 40  // Adjust based on RAM
```

### Container Resources

Edit `internal/docker/client.go`:

```go
Memory:     50 * 1024 * 1024,  // 50MB per container
MemorySwap: 50 * 1024 * 1024,  // No swap
CPUShares:  512,               // 50% CPU priority
```

---

## 🧪 Testing

```bash
# Run all tests
make test

# Run with coverage
make test-coverage

# Unit tests only (skip integration)
make test-short

# With race detector
make test-race
```

**Test Coverage**: 35 tests across 3 packages
- Docker client tests (6 tests, with mocks)
- Session manager tests (9 tests, including concurrency)
- Server tests (20 tests, API + WebSocket + cleanup)

---

## 🐳 Docker Image Details

**Image**: `shellcraft/game:latest`
**Size**: 56.4 MB
**Base**: Alpine Linux 3.19
**Perl**: 5.38.5

**Installed Tools**:
- coreutils, grep, sed, gawk
- findutils, ncurses, bash

**Removed for Security**:
- vi, vim, nano (no editors)
- wget, curl, ssh (no network tools)
- python, ruby, node (no scripting runtimes)

**Game Files**:
- `/usr/local/bin/shellcraft.pl` - Main game loop
- `/usr/local/lib/shellcraft/` - Game modules (Player, Commands, Combat)
- `/sewer/` - Enemy rat files
- `/crypt/` - Harder enemies
- `/etc/scrolls/` - Lore and hints

---

## 🛡️ Security & Resource Management

### Memory Protection
- 50MB hard limit per container
- Swap disabled (prevents thrashing on memory-constrained servers)
- 40 player capacity (safe for 3GB available RAM)
- Automatic cleanup of idle sessions

### Container Isolation
- No external networking
- Restricted command set (no editors, no network tools)
- One container per player
- Containers auto-destroyed on session end

### Capacity Management
- Server rejects new sessions when at capacity (503 response)
- Real-time metrics via `/metrics` endpoint
- Configurable max sessions based on available RAM

---

## 📁 Project Structure

```
shellcraft/
├── cmd/server/              # Main entry point
│   └── main.go
├── internal/
│   ├── docker/              # Docker client abstraction
│   │   ├── client.go        # Real Docker SDK client
│   │   ├── mock.go          # Mock for testing
│   │   └── client_test.go
│   ├── server/              # HTTP/WebSocket server
│   │   ├── server.go        # Router and handlers
│   │   ├── websocket.go     # WebSocket bridge
│   │   ├── frontend.go      # HTML templates
│   │   ├── index.go         # Landing page
│   │   ├── metrics.go       # Metrics endpoint
│   │   ├── cleanup.go       # Background cleanup
│   │   └── *_test.go        # Test files
│   └── session/             # Session management
│       ├── manager.go       # Thread-safe session store
│       └── manager_test.go
├── docker/game-image/       # Perl game shell
│   ├── Dockerfile
│   ├── shellcraft.pl        # Main game loop (240 lines)
│   ├── lib/ShellCraft/
│   │   ├── Player.pm        # Save/load, XP, leveling
│   │   ├── Commands.pm      # Unlock progression
│   │   └── Combat.pm        # File-based combat
│   └── init/
│       ├── welcome.txt      # ASCII art banner
│       └── populate-world.sh
├── Makefile                 # Build commands
├── go.mod                   # Go dependencies
├── LEXICON.md              # Design principles
├── SERVER.md               # TDD implementation plan
├── GAMESHELL.md            # Game specification
├── IMPLEMENTATION.md       # Build log
├── QUICKSTART.md           # 3-minute guide
└── README.md               # This file
```

---

## 🚢 Deployment

### Recommended Specs

- **CPU**: 2+ cores
- **RAM**: 4GB minimum (3GB available for containers)
- **Disk**: 1GB for images
- **Network**: Port 4242 accessible

### Production Checklist

1. **Set appropriate capacity limit**
   ```go
   // internal/server/server.go
   const MaxConcurrentSessions = 40  // Adjust for your RAM
   ```

2. **Configure cleanup**
   ```go
   // cmd/server/main.go
   srv.StartCleanup(5 * time.Minute)  // Check every 5 min
   ```

3. **Set up reverse proxy** (optional)
   ```nginx
   location / {
       proxy_pass http://localhost:4242;
       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection "upgrade";
   }
   ```

4. **Monitor metrics**
   ```bash
   curl http://localhost:4242/metrics
   ```

5. **Set up systemd service** (Linux)
   ```ini
   [Unit]
   Description=ShellCraft Game Server
   After=docker.service

   [Service]
   Type=simple
   User=shellcraft
   WorkingDirectory=/opt/shellcraft
   ExecStart=/opt/shellcraft/bin/shellcraft-server
   Restart=on-failure

   [Install]
   WantedBy=multi-user.target
   ```

---

## 🎨 Customization

### Change Game Content

Edit `docker/game-image/init/populate-world.sh`:
```bash
# Add more enemies
dd if=/dev/urandom of=/sewer/giant_rat.rat bs=1 count=1000

# Add lore files
echo "Secret message..." > /tower/scroll.txt
```

Then rebuild:
```bash
cd docker/game-image
docker build -t shellcraft/game:latest .
```

### Modify Progression

Edit `docker/game-image/lib/ShellCraft/Commands.pm`:
```perl
my %UNLOCKS = (
    0  => [qw(ls cat echo rm cd pwd whoami)],
    1  => ['ls -l'],
    # Add your own unlocks...
);
```

### Adjust Difficulty

Edit `docker/game-image/lib/ShellCraft/Combat.pm`:
```perl
my $base_damage = 20;  # Increase for easier combat
```

Edit `docker/game-image/lib/ShellCraft/Player.pm`:
```perl
return int(100 * (1.5 ** $self->{level}));  # XP curve
```

---

## 🐛 Troubleshooting

### Server won't start
```bash
# Check if port is in use
lsof -i :4242

# Check Docker is running
docker info
```

### Containers not starting
```bash
# Check Docker image exists
docker images | grep shellcraft

# Rebuild if needed
cd docker/game-image && docker build -t shellcraft/game:latest .
```

### Out of memory errors
```bash
# Check server metrics
curl http://localhost:4242/metrics

# Reduce max sessions in server.go
# Or increase server RAM
```

### WebSocket connection fails
```bash
# Check server logs
tail -f /tmp/shellcraft.log

# Verify container is running
docker ps | grep shellcraft
```

---

## 🤝 Contributing

This project follows TDD principles from `LEXICON.md`:

1. **Write tests first** - All features have tests before implementation
2. **Docs → Tests → Implementation → Learnings**
3. **Context is king** - State determines behavior
4. **Infrastructure compounds** - Build tools that enable future work

---

## 📜 License

MIT License - See LICENSE file for details

---

## 🙏 Acknowledgments

Built following:
- TDD best practices
- Unix philosophy (do one thing well)
- "Artifacts are disposable, clarity is durable"
- Hacker culture + retro computing aesthetics

---

## 🎯 Roadmap

**Current**: Phases 1-8 complete (fully playable!)

**Phase 9**: Quest System
- Multi-step objectives
- Quest tracking in save file
- Reward XP on completion

**Phase 10**: More Content
- Procedurally generated enemies
- Boss fights in `/tower`
- Hidden secrets and easter eggs
- More enemy types with unique mechanics

**Phase 11**: Advanced Features
- Multiplayer leaderboard
- Daily challenges
- Achievement system
- Character customization

**Phase 12**: Production Polish
- Persistent storage (Redis/MongoDB)
- Authentication system
- Rate limiting
- Admin dashboard
- Prometheus metrics
- Container pool prewarming

---

**ShellCraft is ready to play!** 🎮⚔️

Visit **http://localhost:4242** and start your adventure!

For detailed implementation notes, see `IMPLEMENTATION.md`.
For quick start guide, see `QUICKSTART.md`.
For game mechanics, see `GAMESHELL.md`.
