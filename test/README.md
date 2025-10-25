# ShellCraft Gameplay Testing DSL

## Overview

The ShellCraft testing DSL allows you to write "speedrun scripts" that simulate gameplay sessions. These tests verify game mechanics, quest solvability, and balance.

## Why a Testing DSL?

**Problem:** Traditional unit tests don't capture gameplay flow
- Can't verify "player fights 3 rats then levels up"
- Hard to test quest chains and progression
- Balance testing requires simulating full sessions

**Solution:** Write tests that read like gameplay walkthroughs
- Express game scenarios naturally
- Verify mechanics holistically
- Serve as both tests and documentation

## DSL API

### Session Management

```perl
my $game = GameTest->new(
    test_name => 'My Test',
    verbose   => 1,           # Print detailed logs
    save_path => '/tmp/test.dat',
);

$game->start_fresh();         # New L0 player
$game->load_save();           # Load existing save
$game->save_game();           # Save current state
```

### Actions

```perl
$game->fight('/sewer/rat.rat');  # Fight an enemy
$game->add_xp(100);              # Add XP directly
$game->set_stats(                # Set stats for testing
    level => 5,
    hp    => 50,
    xp    => 0,
);
```

### Assertions

```perl
$game->expect_level(5);
$game->expect_hp_at_least(80);
$game->expect_hp_at_most(120);
$game->expect_alive();
$game->expect_dead();

$game->expect_can_use('ls -l');
$game->expect_cannot_use('grep -i');
```

### Test Reporting

```perl
$game->report();              # Print test results
exit($game->report() ? 0 : 1);  # Exit with status
```

## Example Test

```perl
#!/usr/bin/env perl
use lib '/usr/local/lib/shellcraft';
use lib '/usr/local/bin/test';
use GameTest;

my $game = GameTest->new(
    test_name => 'First Rat Fight',
    verbose   => 1,
);

# Start fresh L0 player
$game->start_fresh()
     ->expect_level(0)
     ->expect_hp_at_least(100);

# Fight a rat and verify level up
$game->fight('/tmp/test_rat.rat')
     ->expect_level(1)           # Should level up
     ->expect_hp_at_least(100)   # HP restored
     ->expect_can_use('ls -l')   # New command unlocked
     ->save_or_die();

exit($game->report() ? 0 : 1);
```

## Test Categories

### 1. Mechanics Tests
Verify core gameplay systems work:
- Combat damage calculations
- XP and leveling
- HP tracking
- Permadeath

**Example:** `01_basic_combat.t`

### 2. Progression Tests
Simulate gameplay from L0 to target level:
- Verify unlock order
- Check balance (XP curve)
- Ensure progression is achievable

**Example:** `02_progression_speedrun.t`

### 3. Edge Case Tests
Test boundary conditions:
- Death mechanics
- HP edge cases
- Command validation

**Example:** `03_permadeath.t`

### 4. Quest Validation Tests
Verify quest chains are solvable:
- Simulate full quest playthrough
- Check prerequisites
- Verify rewards

**Example:** (future) `quest_sewer_cleanse.t`

## Running Tests

### Single Test
```bash
perl 01_basic_combat.t
```

### All Tests
```bash
./run_tests.sh
```

### In Docker
```bash
docker run --rm shellcraft/game:latest bash -c "cd /usr/local/bin/test && ./run_tests.sh"
```

## Writing New Tests

### 1. Choose a Test Type

**Mechanics Test:**
- Tests a single system (combat, XP, etc.)
- Short and focused
- Name: `XX_system_name.t`

**Speedrun Test:**
- Simulates gameplay session
- Tests progression and balance
- Name: `XX_speedrun_description.t`

**Quest Test:**
- Validates a specific quest
- Ensures it's solvable
- Name: `quest_name.t`

### 2. Test Structure

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/usr/local/bin/test';
use GameTest;

# Create test with descriptive name
my $game = GameTest->new(
    test_name => 'Clear Description',
    verbose   => 1,
);

# Setup
$game->start_fresh();

# Actions and assertions
$game->fight('/tmp/enemy.rat')
     ->expect_level(1)
     ->expect_alive();

# Cleanup
$game->save_or_die();

# Report
exit($game->report() ? 0 : 1);
```

### 3. Best Practices

**Good test names:**
- ✅ `expect_level(5)` - Clear expectation
- ✅ `fight('/sewer/rat.rat')` - Specific enemy
- ❌ `check()` - Too vague

**Chain assertions:**
```perl
# Good - readable flow
$game->fight('/tmp/rat.rat')
     ->expect_level(1)
     ->expect_hp_at_least(80)
     ->save_or_die();

# Bad - breaks flow
$game->fight('/tmp/rat.rat');
$game->expect_level(1);
$game->expect_hp_at_least(80);
```

**Use verbose mode:**
```perl
# Debugging failing test
verbose => 1,  # See all combat output

# Production testing
verbose => 0,  # Silent unless errors
```

## DSL Design Principles

### 1. Fluent Interface
Methods return `$self` for chaining:
```perl
$game->fight(...)
     ->expect_level(5)
     ->save_or_die();
```

### 2. Self-Documenting
Test reads like a gameplay script:
```perl
$game->start_fresh()      # "Start a new game"
     ->fight('/sewer/rat')   # "Fight a rat"
     ->expect_level(1);      # "Should be level 1"
```

### 3. Fail Fast
Assertions fail immediately with clear messages:
```
[FAIL] Expected level 5, got 3
```

### 4. Minimal Boilerplate
Tests focus on gameplay, not setup:
```perl
# DSL handles:
# - Player creation
# - Enemy file creation
# - Combat simulation
# - Output capture
# - Result reporting
```

## Future Enhancements

### Quest DSL
```perl
$game->start_quest('sewer_cleanse')
     ->expect_quest_available()
     ->complete_objective('kill_5_rats')
     ->expect_quest_progress(5, 5)
     ->turn_in_quest()
     ->expect_reward(xp => 500);
```

### Inventory DSL
```perl
$game->expect_item('healing_potion')
     ->use_item('healing_potion')
     ->expect_hp_restored(50);
```

### World State DSL
```perl
$game->expect_file_exists('/sewer/rat_1.rat')
     ->expect_file_size('/sewer/rat_1.rat', 100)
     ->expect_directory_empty('/tower');
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Run Gameplay Tests
  run: |
    docker build -t shellcraft/game:test .
    docker run --rm shellcraft/game:test \
      bash -c "cd /usr/local/bin/test && ./run_tests.sh"
```

### Test Coverage Goals
- ✅ All core mechanics have tests
- ✅ Each quest has validation test
- ✅ Progression L0→L20 verified
- ✅ Edge cases covered

---

**The DSL turns gameplay testing from tedious manual QA into automated, version-controlled "speedruns" that verify game balance and quest solvability.**
