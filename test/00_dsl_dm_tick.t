#!/usr/bin/env perl
# Test: DSL Dungeon Master Tick Simulation
#
# Verifies:
# - trigger_dm_tick() can call dungeon-master --tick
# - Player state is reloaded after DM tick
# - DM tick can be called multiple times
# - Handles permission issues gracefully (DM runs as root)

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

# Create test
# NOTE: Must use /home/soul.dat because DM hardcodes this path
my $game = GameTest->new(
    test_name => 'DSL DM Tick Simulation',
    verbose   => 1,
    save_path => '/home/soul.dat',
);

# Start fresh, set up a quest scenario
$game->start_fresh()
     ->add_quest(1)  # Add Sewer Cleanse quest
     ->expect_quest_active(1)
     ->save_game();

# Test 1: trigger_dm_tick() can be called
$game->trigger_dm_tick();

# Test 2: Player state should be reloaded after tick
# (The DM might have modified soul.dat)
$game->expect_quest_active(1);  # Quest should still be active (no rats killed yet)

# Test 3: Can trigger multiple ticks
$game->trigger_dm_tick()
     ->trigger_dm_tick()
     ->trigger_dm_tick();

# Test 4: Create scenario where DM would modify state
# Kill all rats in sewer (if any exist)
$game->run_command('rm -f /sewer/*.rat');

# Trigger DM - should detect quest completion (0 rats)
$game->trigger_dm_tick();

# Quest should be completed and removed
$game->expect_quest_not_active(1)
     ->expect_xp_at_least(500);  # Should have gained 500 XP from quest

# Report results
exit($game->report() ? 0 : 1);
