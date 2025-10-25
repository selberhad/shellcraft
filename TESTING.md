# ShellCraft Testing Infrastructure

## Overview

ShellCraft includes a Perl-based gameplay testing DSL that simulates player sessions. Tests read like "speedruns" and verify game mechanics, balance, and quest solvability.

## Quick Start

### Run All Tests
```bash
# From project root
cd test
./run_tests.sh
```

### Run Single Test
```bash
# Via volume mount
docker run --rm \
  -v $(pwd)/test/GameTest.pm:/tmp/GameTest.pm:ro \
  -v $(pwd)/test/01_basic_combat.t:/tmp/test.t:ro \
  -e SHELLCRAFT_NO_DELAY=1 \
  -e PERL5LIB=/usr/local/lib/shellcraft:/tmp \
  shellcraft/game:latest \
  perl /tmp/test.t
```

**Important**: Tests are **not included** in the game image to prevent players from seeing quest solutions.

## Test Suite

### Current Tests

1. **00_dsl_filesystem.t** - Tests filesystem assertion DSL methods
2. **00_dsl_commands.t** - Tests command execution DSL methods
3. **00_dsl_dm_tick.t** - Tests DM tick simulation
4. **01_basic_combat.t** - Verifies basic combat mechanics
5. **02_progression_speedrun.t** - Simulates L0→L5 progression
6. **03_permadeath.t** - Tests death and save deletion
7. **04_command_unlocks.t** - Validates command/flag locking
8. **05_quest_system.t** - Tests quest slot unlocking, acceptance, removal, persistence
9. **06_dungeon_master_integration.t** - Tests DM quest completion detection, XP rewards, rat respawn
10. **07_quest_the_crack.t** - Tests L2 quest (The Crack) with PWD-based completion
11. **08_quest_locked_door.t** - Tests L3 quest (Locked Door) with DM transformation

### Example Test

```perl
#!/usr/bin/env perl
use GameTest;

my $game = GameTest->new(
    test_name => 'First Combat',
    verbose   => 1,
);

$game->start_fresh()
     ->expect_level(0)
     ->fight('/tmp/rat.rat')
     ->expect_level(1)
     ->expect_can_use('ls -l')
     ->save_or_die();

exit($game->report() ? 0 : 1);
```

## DSL Features

### Fluent Interface
Chain assertions for readable flow:
```perl
$game->fight('/sewer/rat.rat')
     ->expect_level(5)
     ->expect_alive()
     ->add_quest(1)
     ->expect_quest_active(1)
     ->save_or_die();
```

### Quest Testing DSL
Quest system testing methods:
```perl
$game->add_quest(1)                # Add quest ID 1
     ->expect_quest_active(1)      # Assert quest is active
     ->expect_quest_not_active(2)  # Assert quest not active
     ->expect_quest_slots(2)       # Assert 2 unlocked quest slots
     ->expect_xp(500)              # Assert exact XP amount
     ->expect_xp_at_least(100)     # Assert minimum XP
     ->remove_quest(1);            # Remove quest
```

### Filesystem Testing DSL
Filesystem assertion methods:
```perl
$game->expect_file_exists('/sewer/.crack/.clue')     # Assert file exists
     ->expect_file_not_exists('/tmp/gone.txt')       # Assert file doesn't exist
     ->expect_dir_exists('/sewer/.crack')            # Assert directory exists
     ->expect_dir_not_exists('/tmp/missing')         # Assert dir doesn't exist
     ->expect_file_contains('/path/file', 'pattern') # Assert file contains pattern
     ->create_file('/tmp/test.txt', 'content');      # Create test file
```

### Command Execution DSL
Command execution and testing methods:
```perl
$game->run_command('ls /sewer')                      # Execute shell command
     ->expect_command_success('echo test')           # Assert command exits 0
     ->expect_command_fails('ls /nonexistent');      # Assert command fails

my $output = $game->get_command_output('cat /tmp/file'); # Capture stdout
```

### DM Tick Simulation
Dungeon Master tick testing:
```perl
$game->trigger_dm_tick();  # Execute DM tick, reload player state
```
Note: DM uses `/home/soul.dat`, so tests must use that save path for DM quest checks.

### Automatic Enemy Creation
Tests create appropriately-sized enemies:
```perl
$game->fight('/tmp/rat_small.rat');   # 100 bytes
$game->fight('/tmp/skeleton.rat');    # 800 bytes
$game->fight('/tmp/daemon.rat');      # 1200 bytes
```

### Fast Execution
Combat delays are disabled in tests via `SHELLCRAFT_NO_DELAY=1` env var.

## Environment Variables

- `SHELLCRAFT_NO_DELAY=1` - Skip combat delays (set automatically by test runner)

## Writing Tests

See `docker/game-image/test/README.md` for complete documentation on:
- Test structure
- Available assertions
- Best practices
- DSL API reference

## Integration

### CI/CD Example
```yaml
- name: Test ShellCraft
  run: |
    docker build -t shellcraft/game:test .
    docker run --rm shellcraft/game:test \
      bash -c "cd /usr/local/bin/test && ./run_tests.sh"
```

### Makefile Target
```makefile
test-game:
	docker build -t shellcraft/game:latest docker/game-image
	docker run --rm shellcraft/game:latest \
		bash -c "cd /usr/local/bin/test && ./run_tests.sh"
```

## Design Philosophy

**Tests as Speedruns**
- Express gameplay scenarios naturally
- Verify mechanics holistically
- Serve as both tests and documentation

**Fail Fast**
- Clear error messages
- Immediate assertion failures
- Detailed logging in verbose mode

**Minimal Boilerplate**
- DSL handles setup/teardown
- Focus on gameplay flow
- Chain assertions for readability

---

For detailed API documentation, see: `docker/game-image/test/README.md`
