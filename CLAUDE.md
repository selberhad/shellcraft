# ShellCraft - Claude Code Working Guide

## Project Overview

**ShellCraft** is a fantasy-themed UNIX shell RPG teaching real command-line skills through gameplay. Players level up by executing commands, fighting file-based enemies, and unlocking new tools progressively (L0→L42).

**Architecture:**
- **Go server** - Orchestrates Docker containers, WebSocket terminal bridge, session management
- **Perl game shell** - In-container RPG engine with command validation, combat, progression
- **Rust binaries** - Compiled game utilities (quest system) embedded in game image
- **Web frontend** - xterm.js terminal interface

---

## Critical Rules

### 0. NEVER Run `docker build` Directly

**CRITICAL:** Always use the build script, never run `docker build` manually.

```bash
# ✅ CORRECT - Use the build script
./build-game-image.sh

# ❌ WRONG - Never do this
docker build -t shellcraft/game:latest .
docker build -f docker/game-image/Dockerfile .
cd docker/game-image && docker build .
```

**Why:** The build script handles the correct build context from the project root. Running `docker build` from the wrong directory will fail because the Dockerfile COPYs paths relative to the project root.

### 1. Multi-Stage Docker Build (DO NOT BREAK)

The `docker/game-image/Dockerfile` uses a **multi-stage build**:

```dockerfile
FROM alpine:3.19 AS builder
# Build Rust binaries (quest, etc.)

FROM alpine:3.19
# Copy ONLY compiled binaries, NOT source code
```

**Why:** Players must NOT see:
- Rust source code (reveals quest mechanics)
- Test files (spoil solutions)
- Build toolchain (security)

**What goes in the image:**
- ✅ Compiled Perl game shell
- ✅ Compiled Rust binaries (`/home/quest`)
- ✅ Pre-populated world files (rats, lore)
- ❌ NO Rust source code
- ❌ NO test files (mounted at runtime only)
- ❌ NO development tools

### 2. Test Files Are Mounted, Not Baked

Tests live in `test/` and are **mounted via Docker volumes** at runtime:

```bash
docker run --rm \
  -v $(pwd)/test/GameTest.pm:/tmp/GameTest.pm:ro \
  -v $(pwd)/test/01_basic_combat.t:/tmp/test.t:ro \
  shellcraft/game:latest perl /tmp/test.t
```

**Never include test files in the Docker image.** They must remain external.

### 3. Binary Format: soul.dat

Player state is stored in `/home/soul.dat` (binary format, see SOUL_SPEC.md):
- Magic bytes: "SHC!" (0x53 0x48 0x43 0x21)
- Fields: level (u32), XP (u64), quest slots (u32[8])
- **HP is file size**: Encoded as null-byte padding (telomeres)
- See SOUL_SPEC.md for complete format specification

**When modifying:** Ensure Perl (Player.pm) and Rust (libsoul) stay in sync.

### 4. Dungeon Master (Root Cron)

Background process that orchestrates the game world:
- **Location**: `/usr/sbin/dungeon-master` (root-only, chmod 700)
- **Schedule**: Runs every minute via cron
- **Responsibilities**:
  - Check quest completion conditions (e.g., Sewer Cleanse: 0 rats)
  - Award XP and remove completed quests from soul.dat
  - Repopulate monsters (rats: 25% chance per tick, max 5)
- **Security**: Player cannot access or kill DM process
- **Testing**: Use `dungeon-master --tick` for manual tick execution

---

## Project Structure

```
shellcraft/
├── cmd/server/           # Go server entrypoint
├── internal/
│   ├── docker/          # Docker SDK wrapper + mocks
│   ├── server/          # HTTP/WebSocket handlers, cleanup
│   └── session/         # Session lifecycle manager
├── docker/game-image/
│   ├── Dockerfile       # Multi-stage build (CRITICAL)
│   ├── shellcraft.pl    # Perl game loop
│   ├── dungeon-master.pl # Root cron process (world orchestration)
│   ├── lib/ShellCraft/  # Perl modules (Player, Combat, Commands)
│   └── init/            # World population scripts
├── rust-bins/
│   ├── quest/           # Quest management binary (/home/quest)
│   └── libsoul/         # Shared soul.dat library
├── test/
│   ├── *.t              # Gameplay tests (Perl DSL)
│   ├── GameTest.pm      # Test framework
│   └── run_tests.sh     # Test runner (mounts tests into container)
└── *.md                 # Documentation
```

---

## Component Interactions

### Player Session Flow
1. **Go server** receives HTTP request → creates Docker container
2. **Container** starts cron daemon (root) then drops to `player` user
3. **Player** runs `shellcraft.pl` (Perl game shell)
4. **WebSocket** bridges browser ↔ container I/O
5. **Player** executes commands → Perl validates against level
6. **Combat** (`rm` on .rat files) → updates XP/HP in `soul.dat`
7. **DM cron** ticks every minute (invisible to player)
8. **Cleanup** goroutine removes idle sessions after 15min

### Quest Workflow
1. **Player** runs `/home/quest` binary
2. **Quest binary** reads soul.dat, checks available quests
3. **Player** accepts quest (e.g., Sewer Cleanse: kill all rats)
4. **Player** completes objective (kills all rats in /sewer)
5. **DM** detects completion on next tick (0 rats remaining)
6. **DM** awards XP (500 XP) and removes quest from soul.dat
7. **DM** gradually respawns rats (25% per tick, max 5)

### Test Flow
1. `test/run_tests.sh` iterates over `*.t` files
2. Each test **mounts** `GameTest.pm` and test file into container
3. Perl DSL simulates gameplay (fight, expect_level, etc.)
4. Tests verify mechanics without revealing solutions to players

---

## Development Workflows

### Build Go Server
```bash
make build              # → bin/shellcraft-server
make test               # Go unit tests (35 tests)
make test-short         # Skip integration tests
```

### Build Game Image
```bash
cd docker/game-image
docker build -t shellcraft/game:latest .
```

**Build stages:**
1. Compile Rust binaries in builder stage
2. Copy binaries to runtime Alpine image
3. Install Perl + game files
4. Populate world (`/sewer`, `/crypt`, etc.)

### Run Server Locally
```bash
make run                # Starts on :8080
# Or manually:
./bin/shellcraft-server
```

**Environment variables:**
- `PORT` - HTTP port (default: 8080)
- `SHELLCRAFT_IMAGE` - Game container image

### Run Gameplay Tests
```bash
cd test
./run_tests.sh          # Runs all *.t files
```

**Test structure:**
```perl
use GameTest;

my $game = GameTest->new(test_name => 'Combat Test', verbose => 1);

$game->start_fresh()
     ->expect_level(0)
     ->fight('/tmp/rat.rat')
     ->expect_level(1)
     ->expect_can_use('ls -l')
     ->save_or_die();
```

---

## Key Files to Know

### Documentation (Read First)
- **VISION.md** - Aesthetic guide, lore, cultural references, hackathon theme alignment
- **LEXICON.md** - Development philosophy and guidance vectors
- **GAME_DESIGN.md** - Canonical game design spec (mechanics, progression, lore, balance)
- **LEVELS.md** - Complete L0-L42 command unlock table and stat progression
- **SOUL_SPEC.md** - Binary savefile format
- **SERVER.md** - Go server TDD implementation plan
- **TESTING.md** - Test infrastructure overview

### Game Engine (Perl)
- **shellcraft.pl** - Main game loop, command parsing
- **lib/ShellCraft/Player.pm** - Level, XP, HP, save/load
- **lib/ShellCraft/Combat.pm** - File-based enemy combat
- **lib/ShellCraft/Commands.pm** - Command unlock validation

### Server (Go)
- **cmd/server/main.go** - Entrypoint
- **internal/server/server.go** - HTTP API, WebSocket upgrade
- **internal/session/manager.go** - Thread-safe session tracking
- **internal/docker/client.go** - Docker SDK wrapper

### Quest System (Rust)
- **rust-bins/quest/quests.txt** - Quest text data (simple key=value format)
- **rust-bins/quest/src/quest_data.rs** - Zero-dependency parser (compile-time)
- **rust-bins/quest/src/main.rs** - Quest journal and offering logic
- **rust-bins/libsoul/src/lib.rs** - Soul.dat I/O library

### Tests
- **test/GameTest.pm** - Fluent testing DSL
- **test/run_tests.sh** - Test runner with volume mounts
- **test/*.t** - Gameplay tests (combat, progression, permadeath)

---

## Common Tasks

### Add New Command Unlock

1. Edit `lib/ShellCraft/Commands.pm`:
   ```perl
   $COMMAND_UNLOCKS{7} = ['grep', 'grep pattern'];
   ```

2. Update tests in `test/04_command_unlocks.t`:
   ```perl
   $game->level_up_to(7)
        ->expect_can_use('grep')
        ->expect_cannot_use('grep -i');
   ```

3. Update `LEVELS.md` unlock table

### Modify XP Formula

**Files to update:**
- `lib/ShellCraft/Player.pm` - `xp_for_next_level()` method
- `test/GameTest.pm` - `xp_for_level()` helper (keep in sync!)
- `GAME_DESIGN.md`, `README.md` - Documentation
- All tests that use `level_up_once()` or check XP values

**Current formula:** `fibonacci(level + 2) * 1000`

### Add Rust Binary

1. Create new binary:
   ```bash
   cd rust-bins
   cargo new --bin mybinary
   ```

2. Add to workspace in `rust-bins/Cargo.toml`:
   ```toml
   members = ["libsoul", "quest", "mybinary"]
   ```

3. Update `Dockerfile` to copy binary:
   ```dockerfile
   COPY --from=builder /build/rust-bins/target/release/mybinary /home/mybinary
   RUN chmod +x /home/mybinary
   ```

### Add New Quest

**Quest text is data-driven** - all quest content lives in `rust-bins/quest/quests.txt` using a simple custom format.

1. Edit `rust-bins/quest/quests.txt`:
   ```
   %% QUEST 6
   id=6
   name=My New Quest
   min_level=7
   reward_xp=21000
   offer_title=My New Quest
   offer_narrative="""
   This is the narrative shown when the quest
   is first offered to the player.
   Multi-line strings use triple quotes.
   """
   offer_objective=Do something cool
   offer_reward=21000 XP
   journal_description="""
   This shows in the quest journal while active.
   """
   journal_objective=Optional objective hint
   journal_reward=21000 XP
   completion_message=Optional completion message
   ```

2. Add quest constant to `rust-bins/quest/src/main.rs`:
   ```rust
   const QUEST_MY_NEW_QUEST: u32 = 6;
   ```

3. Add quest offer logic in `main()`:
   ```rust
   else if level >= 7 && !soul.has_quest(QUEST_MY_NEW_QUEST) {
       offer_quest(&mut soul, QUEST_MY_NEW_QUEST, &quests);
   }
   ```

4. If quest needs progress tracking, add to `check_quest_progress()`:
   ```rust
   QUEST_MY_NEW_QUEST => {
       let is_complete = check_some_condition();
       let msg = format!("Progress: {}/{}", current, total);
       (is_complete, Some(msg))
   }
   ```

5. Add Dungeon Master completion logic in `dungeon-master.pl` if needed

6. Add quest test in `test/` directory

**Note:** Quest text is parsed at compile-time via `include_str!()`, so no external dependencies or runtime file I/O. Format is simple key=value with `"""..."""` for multi-line strings.

### Modify soul.dat Format

**DANGER:** Breaking change. Must update in lockstep:
1. `SOUL_SPEC.md` - Update binary layout table
2. `lib/ShellCraft/Player.pm` - `save()` and `load_or_create()`
3. `rust-bins/libsoul/src/lib.rs` - Struct definition, read/write
4. Increment version number (u16 at offset 0x04)
5. Add migration logic for old saves (optional)

---

## Testing Strategy

### Test Pyramid

**Unit Tests (Go):**
- Mock Docker client for isolation
- Fast execution (~0.5s)
- 35 tests covering server, session, cleanup

**Unit Tests (Rust):**
- `libsoul` library tests (soul.dat I/O)
- Tests: save/load roundtrip, validation, quest management
- Run: `cd rust-bins && cargo test`
- 7 tests covering binary format parsing

**Integration Tests (Perl DSL):**
- Full gameplay simulation
- Mounted into real containers
- Verify mechanics + balance

**Test Coverage:**
- ✅ Go server (35 tests)
- ✅ Rust libsoul (7 tests)
- ✅ Combat mechanics (01_basic_combat.t)
- ✅ Progression L0→L5 (02_progression_speedrun.t)
- ✅ Permadeath (03_permadeath.t)
- ✅ Command unlocks (04_command_unlocks.t)
- ✅ Quest system API (05_quest_system.t)
- ✅ Dungeon Master integration (06_dungeon_master_integration.t)

### Running Tests

```bash
# Go unit tests (fast)
make test-short

# Go tests with Docker (integration)
make test-integration

# Rust unit tests (soul.dat I/O)
cd rust-bins && cargo test

# Perl gameplay tests (requires image)
cd test && ./run_tests.sh

# Single gameplay test
docker run --rm \
  -v $(pwd)/test/GameTest.pm:/tmp/GameTest.pm:ro \
  -v $(pwd)/test/01_basic_combat.t:/tmp/test.t:ro \
  -e SHELLCRAFT_NO_DELAY=1 \
  shellcraft/game:latest perl /tmp/test.t
```

---

## Debugging

### Debug Perl Game Shell

```bash
# Run game interactively
docker run -it --rm shellcraft/game:latest

# Inspect soul.dat (see SOUL_SPEC.md for format)
docker run -it --rm shellcraft/game:latest sh
# Inside container:
ls -l /home/soul.dat
hexdump -C /home/soul.dat | head -20
```

### Debug Go Server

```bash
# Enable verbose logging (edit code or add flag)
go run ./cmd/server/main.go

# Check Docker connectivity
docker ps
docker logs <container_id>

# Test WebSocket manually (websocat tool)
websocat ws://localhost:8080/session/SESSION_ID/ws
```

### Debug Tests

```perl
# In test file, enable verbose mode:
my $game = GameTest->new(
    test_name => 'Debug Test',
    verbose   => 1,  # Print detailed logs
);
```

---

## Common Mistakes to Avoid

### ❌ Breaking the Dockerfile
**Problem:** Removing Rust build stage or builder copy
**Impact:** Game binaries missing, containers fail to start
**Fix:** Always preserve multi-stage build structure

### ❌ Baking Tests Into Image
**Problem:** Adding test files via `COPY` instead of volume mount
**Impact:** Players can read test solutions, spoiling the game
**Fix:** Tests must always use `-v` volume mounts

### ❌ Desync Between Perl and Rust
**Problem:** Changing soul.dat format in only one place
**Impact:** Save corruption, game crashes
**Fix:** Update both `Player.pm` and `libsoul/src/lib.rs` together

### ❌ Forgetting Test Updates
**Problem:** Changing XP formula without updating tests
**Impact:** All progression tests fail
**Fix:** Update `test/GameTest.pm` helpers when changing mechanics

### ❌ Using Wrong XP Offset
**Problem:** Reading XP at wrong byte offset in soul.dat
**Current:** XP is at 0x12-0x19 (u64 LE), NOT 0x12-0x15 (u32)
**Fix:** Always check SOUL_SPEC.md for current layout

---

## Performance Notes

- **Session creation:** ~50ms (includes image pull on first request)
- **WebSocket latency:** <10ms (local)
- **Container limit:** 40 concurrent (configurable)
- **Memory per session:** ~2MB
- **Cleanup interval:** 5 minutes (15min idle timeout)

---

## Future Work (Not Implemented)

From SERVER.md Phase 8-10:
- Redis session persistence (survive restarts)
- Authentication/authorization
- Rate limiting
- Prometheus metrics
- Container pool prewarming

---

## Philosophy (from LEXICON.md)

**Key Principles:**
- **Docs → Tests → Implementation → Learnings** - TDD cycle
- **Context is king** - State determines possibilities
- **Artifacts are disposable, clarity is durable** - Generation is cheap
- **Infrastructure compounds** - Each tool enables new workflows
- **Refactor early, not late** - Token costs are immediate, not future debt
- **The human always knows best** - Execute instructions, don't editorialize

---

## Quick Reference

### Build Everything
```bash
make deps                         # Install Go dependencies
cd docker/game-image && docker build -t shellcraft/game:latest .
make build                        # Build server
```

### Test Everything
```bash
make test-short                   # Go unit tests
cd rust-bins && cargo test        # Rust unit tests
cd test && ./run_tests.sh         # Perl gameplay tests
```

### Run Locally
```bash
./bin/shellcraft-server           # Server on :8080
# In browser: http://localhost:8080
```

### File Locations
- Go server: `cmd/server/`, `internal/`
- Perl game: `docker/game-image/lib/ShellCraft/`
- Rust binaries: `rust-bins/`
- Tests: `test/`
- Docs: `*.md` in root

---

**When in doubt, read VISION.md for aesthetic/lore guidance, LEXICON.md for philosophy, and the relevant spec file (GAME_DESIGN.md, LEVELS.md, SOUL_SPEC.md, SERVER.md) for implementation details.**
