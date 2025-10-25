#!/usr/bin/env perl
# Test: L3 Quest - The Locked Door
#
# Part 1: Discovery (Phase 5.a) - Find locked door in .crack/
# Part 2: Transformation (Phase 6.a) - Create key, DM transforms door to under_nix/
#
# Verifies:
# - Player at L3 has touch command unlocked
# - locked_door file exists in /sewer/.crack/
# - Can read locked_door file
# - Create key file with touch
# - DM detects key and transforms door → under_nix/ directory

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

# Create test
# NOTE: Must use /home/soul.dat because DM hardcodes this path
my $game = GameTest->new(
    test_name => 'L3 Quest: The Locked Door',
    verbose   => 1,
    save_path => '/home/soul.dat',
);

# === PART 1: Door Discovery (L3) ===

# Start at L0, level up to L3
$game->start_fresh()
     ->expect_level(0);

# Level to L3
$game->add_xp(1000)      # L0 -> L1
     ->level_up_once()   # L1 -> L2
     ->level_up_once()   # L2 -> L3
     ->expect_level(3)
     ->expect_can_use('touch')  # L3 should have touch unlocked
     ->add_quest(3)              # Add "Locked Door" quest (ID=3)
     ->expect_quest_active(3);

# Test 1: locked_door file exists in .crack/
$game->expect_file_exists('/sewer/.crack/locked_door');

# Test 2: Can read the locked_door file
$game->expect_file_contains('/sewer/.crack/locked_door', 'key');  # Mentions needing a key

# === PART 2: Key Creation and Door Transformation (Phase 6.a) ===
# This part will fail initially, implemented in Phase 6.b

# Test 3: Create a key file using touch
$game->run_command('touch /sewer/.crack/key')
     ->expect_file_exists('/sewer/.crack/key');

# Test 4: Save game and trigger DM tick
$game->save_game()
     ->trigger_dm_tick();

# Test 5: DM should transform locked_door → under_nix/ directory
$game->expect_file_not_exists('/sewer/.crack/locked_door')  # Door file removed
     ->expect_dir_exists('/sewer/.crack/under_nix')          # New directory created
     ->expect_file_not_exists('/sewer/.crack/key');          # Key consumed

# Test 6: Quest should be completed and reward given
$game->expect_quest_not_active(3)  # Quest 3 removed
     ->expect_xp_at_least(3000);    # Should have gained 3000 XP

# Report results
exit($game->report() ? 0 : 1);
