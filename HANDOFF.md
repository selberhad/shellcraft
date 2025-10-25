# Development Handoff: L2-L6 Quest Implementation

**Date:** 2025-10-24
**Context:** 24-hour Fantasy OS hackathon (12 hours remaining)
**Current State:** Planning complete, ready for TDD implementation
**Next Action:** Execute PLAN.md Phase 1.a

---

## Project Status

### What's Implemented
- ✅ L0-L1 progression with Sewer Cleanse quest (killing rats)
- ✅ Combat system (file-based enemies, turn-based)
- ✅ Quest system (Rust binary + Perl integration)
- ✅ Dungeon Master (root cron process for quest completion)
- ✅ Command unlocking system (progressive flag/command unlocks)
- ✅ Save system (binary soul.dat with telomere HP mechanic)
- ✅ Test DSL (GameTest.pm with fluent assertions)
- ✅ Docker-based game environment (Alpine + Perl)
- ✅ WebSocket terminal (Go server + xterm.js frontend)

### What's Designed (Not Implemented)
- ❌ L2-L6 quests (see LEVELS.md and PLAN.md)
- ❌ Under-Nix symlink maze
- ❌ DM door transformation mechanics
- ❌ DSL extensions for filesystem/command testing
- ❌ Updated command unlock progression (L1=ls -s, L2=ls -a, etc.)

---

## Critical Context for Implementation

### Game Design Philosophy
**READ VISION.md FIRST** - Core principle:
- **Real UNIX commands with real output** (pedagogical first!)
- Flavor comes from **file names** (.rat, .elf) and **quest narrative**
- **NOT from hijacking command output** with flavor text
- This is **Advent of Code for UNIX**, not a combat game
- Combat is just the first mechanic; real game is CTF-style puzzles

### Level Progression (L0-L6)
From LEVELS.md:
- **L0:** ls, cat, echo, rm, cd, pwd, whoami (tutorial)
- **L1:** ls -s (file sizes for rat combat - Sewer Cleanse quest)
- **L2:** ls -a (discover hidden .crack/ directory)
- **L3:** touch (create key file → DM transforms locked_door to under_nix/)
- **L4:** ls -R (try on symlink maze, hangs on circular links, learn Ctrl+C)
- **L5:** ln -s (create portal from /home to under_nix, learn what symlinks are)
- **L6:** ls -l (see symlink targets with ->, solve the maze)

### Quest Flow (L2-L6 Arc)
This is a **metroidvania-style progression**:
1. L2: Discover .crack/ hidden in /sewer
2. L3: Create key file, DM transforms door → portal to Under-Nix
3. L4: Try to explore Under-Nix, realize you're stuck (circular symlinks)
4. L5: Learn symlinks by creating your own (portal shortcut)
5. L6: Return to maze with ls -l, can now trace symlink targets and solve

**Key insight:** Players discover Under-Nix at L3 but can't solve it until L6.

---

## Architecture Notes

### Testing Infrastructure
**Location:** `/Users/emadum/Code/shellcraft/test/`
**Key files:**
- `GameTest.pm` - Fluent test DSL (extend this in Phase 1)
- `run_tests.sh` - Test runner (mounts tests into Docker)
- `01-06_*.t` - Existing tests (see TESTING.md)

**Important:** Tests are **mounted via volumes**, NOT baked into image (prevents spoilers).

**Running tests:**
```bash
cd test
./run_tests.sh                    # All tests
./run_tests.sh 01_basic_combat.t  # Single test
```

**Environment:**
- `SHELLCRAFT_NO_DELAY=1` - Disables combat delays in tests (auto-set)
- `PERL5LIB=/usr/local/lib/shellcraft:/tmp` - Module path

### Dungeon Master
**Location:** `/Users/emadum/Code/shellcraft/docker/game-image/dungeon-master.pl`
**Runs:** Every minute via root cron, or manually with `--tick`

**Current responsibilities:**
1. Check Sewer Cleanse quest (count rats, award 500 XP if 0 rats)
2. Respawn rats (25% chance per tick, max 5)

**Need to add (Phase 3-6):**
1. Check for key file in .crack/, transform locked_door → under_nix/
2. Check for /home/portal symlink, award Portal quest XP
3. Check for treasure file interaction, award Maze quest XP

**Pattern:**
```perl
sub check_new_quest {
    my ($player) = @_;
    if ($player->has_quest(QUEST_ID)) {
        if (condition_met()) {
            $player->add_xp(REWARD_XP);
            $player->remove_quest(QUEST_ID);
            return 1;
        }
    }
    return 0;
}
```

### Command Unlocking
**Location:** `/Users/emadum/Code/shellcraft/docker/game-image/lib/ShellCraft/Commands.pm`
**Current system:** Hash of level → unlocked commands

**NEEDS UPDATE (Phase 8):**
```perl
# OLD (wrong progression):
$COMMAND_UNLOCKS{1} = ['ls -l'];
$COMMAND_UNLOCKS{2} = ['mkdir'];

# NEW (correct progression):
$COMMAND_UNLOCKS{1} = ['ls -s'];
$COMMAND_UNLOCKS{2} = ['ls -a'];
$COMMAND_UNLOCKS{3} = ['touch'];
$COMMAND_UNLOCKS{4} = ['ls -R'];
$COMMAND_UNLOCKS{5} = ['ln', 'ln -s'];
$COMMAND_UNLOCKS{6} = ['ls -l'];
```

### World Initialization
**Location:** `/Users/emadum/Code/shellcraft/docker/game-image/init/`
**Files:**
- `populate_sewer.sh` - Creates /sewer with 5 rats
- `populate_crypt.sh` - Creates /crypt with skeletons/daemons
- `create_scrolls.sh` - Creates /etc/scrolls lore files

**NEEDS UPDATE (Phase 2-4):**
- Add `.crack/` directory to /sewer
- Add `locked_door` file to .crack/
- Create symlink maze structure (used by DM transformation)

**Pattern:**
```bash
# Create hidden directory
mkdir -p /sewer/.crack
echo "You found a crack in the sewer wall..." > /sewer/.crack/.clue

# Create locked door
echo "This lock looks like it needs a key to be unlocked. Obviously." > /sewer/.crack/locked_door
```

---

## TDD Workflow

### Red-Green-Refactor Cycle
1. **Write failing test** (red)
   - Create test file in `test/`
   - Run: `./run_tests.sh new_test.t`
   - Verify it fails with expected error
2. **Implement minimum code** (green)
   - Modify Perl/Rust/shell scripts
   - Rebuild Docker image: `docker build -t shellcraft/game:latest docker/game-image`
   - Re-run test, verify it passes
3. **Refactor if needed**
   - Clean up code
   - Verify tests still pass
4. **Commit when green**

### Docker Build Commands
```bash
# Build game image (from project root)
docker build -t shellcraft/game:latest docker/game-image

# Run single test
docker run --rm \
  -v $(pwd)/test/GameTest.pm:/tmp/GameTest.pm:ro \
  -v $(pwd)/test/NEW_TEST.t:/tmp/test.t:ro \
  -e SHELLCRAFT_NO_DELAY=1 \
  -e PERL5LIB=/usr/local/lib/shellcraft:/tmp \
  shellcraft/game:latest \
  perl /tmp/test.t

# Run all tests
cd test && ./run_tests.sh
```

### Common Pitfalls
1. **Forgetting to rebuild Docker image** after code changes
2. **Tests not seeing latest code** - always rebuild before running tests
3. **Permission issues** with DM - tests may not run as root
4. **File paths** - tests run in container, use absolute paths
5. **Soul.dat format** - see SOUL_SPEC.md if touching binary format

---

## Quest IDs

**Assigned IDs:**
- **1:** Sewer Cleanse (implemented)
- **2:** Portal Home (L5 - to be implemented)
- **3:** Navigate Maze (L6 - to be implemented)

**Note:** L2, L3, L4 quests are **discovery/exploration**, not tracked by DM.
Only Portal Home (L5) and Navigate Maze (L6) award XP via DM.

---

## XP & Leveling Reference

**XP Formula:** `fibonacci(level + 2) * 1000`
- L0→L1: 1,000 XP (fib(2) = 1)
- L1→L2: 2,000 XP (fib(3) = 2)
- L2→L3: 3,000 XP (fib(4) = 3)
- L3→L4: 5,000 XP (fib(5) = 5)
- L4→L5: 8,000 XP (fib(6) = 8)
- L5→L6: 13,000 XP (fib(7) = 13)

**Quest Rewards:**
- Sewer Cleanse: 500 XP (implemented)
- Portal Home: 300 XP (proposed)
- Navigate Maze: 500 XP (proposed)

**Leveling Strategy:**
- Combat XP + Quest XP should allow progression L0→L6
- Players should need to kill rats AND complete quests
- Not just grinding rats to L6

---

## File Locations Quick Reference

### Documentation
- `VISION.md` - Aesthetic/lore guide (READ FIRST)
- `LEVELS.md` - L0-L42 command progression
- `PLAN.md` - TDD implementation plan (EXECUTE THIS)
- `GAME_DESIGN.md` - Mechanics, combat, balance
- `SOUL_SPEC.md` - Binary save format
- `CLAUDE.md` - Development guide for AI

### Game Code
- `docker/game-image/shellcraft.pl` - Main game loop
- `docker/game-image/lib/ShellCraft/Player.pm` - Player stats, save/load
- `docker/game-image/lib/ShellCraft/Combat.pm` - Turn-based combat
- `docker/game-image/lib/ShellCraft/Commands.pm` - Command unlocking
- `docker/game-image/dungeon-master.pl` - World orchestration

### Quest System
- `rust-bins/quest/src/main.rs` - Quest binary (shows active quests)
- `rust-bins/libsoul/src/lib.rs` - soul.dat I/O library

### Tests
- `test/GameTest.pm` - Test DSL
- `test/run_tests.sh` - Test runner
- `test/*.t` - Test files

---

## Known Issues / Tech Debt

1. **ls -l was never properly added** - Currently shows as L1 unlock but needs to be L6
2. **Command validation** may have bugs with new progression
3. **No quest UI** - Players must run `./quest` binary to see quests
4. **DM runs as root** - Tests may not be able to execute DM tick (handle gracefully)
5. **No Ctrl+C simulation** in tests - Phase 4.a needs timeout mechanism

---

## Session Context

### What We Discussed
1. Documentation consolidation (merged GAMESHELL.md → GAME_DESIGN.md)
2. Created VISION.md with Editor Wars lore, Wyrm mythology, McKenna/RAW voice
3. Redesigned L0-L6 from combat-focused to puzzle-focused
4. Planned Under-Nix symlink maze as metroidvania progression
5. Removed purple prose, emphasized pedagogical UNIX over flavor text
6. Created comprehensive TDD plan

### Decisions Made
- Game is **Advent of Code for UNIX**, not RPG combat simulator
- Commands output **real UNIX**, flavor is in **world structure**
- L1 gets `ls -s` (not `ls -l`) for simpler combat intro
- `ls -l` delayed until L6 (when players need to see symlink targets)
- Under-Nix discovered at L3 but unsolvable until L6
- Symlink maze has circular links (teaches Ctrl+C at L4)

### What Was Punted
- L7-L42 progression (out of scope for hackathon)
- Gibson endgame quest (L42 content)
- Multiplayer features
- Sound/visual effects
- Advanced quest types beyond L6

---

## Next Session: Start Here

1. **Read VISION.md** (5 min) - Understand aesthetic/philosophy
2. **Read LEVELS.md L0-L6 section** (2 min) - Understand progression
3. **Read PLAN.md** (5 min) - Understand TDD plan
4. **Execute Phase 1.a** - Write first failing test:
   - File: `test/00_dsl_filesystem.t`
   - Test `expect_file_exists()`, `expect_dir_exists()`, `expect_file_contains()`
   - See PLAN.md Phase 1.a for details

5. **Follow TDD cycle:**
   - Write test → Run (fails red) → Implement → Run (passes green) → Commit
   - Repeat for all 11 phases

**Time estimate:** ~6-8 hours for all phases (feasible for hackathon)

---

## Emergency Contacts / Resources

- **CLAUDE.md** - Full development guide for AI assistance
- **TESTING.md** - Test infrastructure overview
- **LEXICON.md** - Development philosophy
- Git history - All recent commits have detailed messages

**If stuck:** Check existing tests (01-06_*.t) for patterns, read GameTest.pm DSL code.

---

**Good luck! The game design is solid. Just execute the plan. 🚀**
