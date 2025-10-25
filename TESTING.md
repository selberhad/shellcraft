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

1. **01_basic_combat.t** - Verifies basic combat mechanics
2. **02_progression_speedrun.t** - Simulates L0→L5 progression
3. **03_permadeath.t** - Tests death and save deletion
4. **04_command_unlocks.t** - Validates command/flag locking

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
     ->save_or_die();
```

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
