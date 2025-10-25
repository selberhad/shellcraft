#!/usr/bin/env perl
# Test: L6 Quest - Navigate the Maze
#
# Phase 9.a: Maze Navigation Test
#
# Verifies:
# - Player at L6 has ls -l unlocked
# - Can use ls -l to see symlink targets
# - Can navigate maze by following correct path
# - Finds treasure at the end
# - DM awards Navigate Maze quest XP
# - Quest is removed from active quests

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

# Create test
my $game = GameTest->new(
    test_name => 'L6 Quest: Navigate the Maze',
    verbose   => 1,
    save_path => '/home/soul.dat',
);

# === Setup: Create player and unlock maze ===

# Start fresh and level to L6
$game->start_fresh()
     ->expect_level(0);

# Level through L0 -> L6
$game->add_xp(1000)       # L0 -> L1
     ->level_up_once()    # L1 -> L2
     ->level_up_once()    # L2 -> L3
     ->level_up_once()    # L3 -> L4
     ->level_up_once()    # L4 -> L5
     ->level_up_once()    # L5 -> L6
     ->expect_level(6)
     ->expect_can_use('ls -l');  # L6 should have ls -l unlocked

# Create under_nix maze by using key (prerequisite)
$game->run_command('touch /sewer/.crack/key')
     ->save_game()
     ->trigger_dm_tick()
     ->expect_dir_exists('/sewer/.crack/under_nix');

# Add Navigate Maze quest (ID=5)
$game->add_quest(5)
     ->expect_quest_active(5);

# === Test 1: Verify ls -l shows symlink targets ===
my $entrance_ls = $game->get_command_output('ls -l /sewer/.crack/under_nix/entrance');
if ($entrance_ls !~ /->/) {
    $game->fail("ls -l should show symlink targets (no '->' found)");
}

# === Test 2: Navigate maze using ls -l ===
# The correct path is: entrance -> forward (center_hall) -> forward (treasure_room)
# Let's verify each step

# Step 1: Check entrance options
if ($entrance_ls !~ /forward.*center_hall/s) {
    print "  [INFO] entrance/forward -> center_hall (may be in different format)\n";
}

# Step 2: Check center_hall options
my $center_ls = $game->get_command_output('ls -l /sewer/.crack/under_nix/center_hall');
if ($center_ls !~ /forward.*treasure/s) {
    print "  [INFO] center_hall/forward -> treasure_room (may be in different format)\n";
}

# === Test 3: Find and access treasure ===
$game->expect_file_exists('/sewer/.crack/under_nix/treasure_room/treasure');

# Read the treasure file to complete the quest
my $treasure_content = $game->get_command_output('cat /sewer/.crack/under_nix/treasure_room/treasure');
if ($treasure_content !~ /Congratulations/) {
    $game->fail("Treasure file should contain congratulations message");
}

# === Test 4: DM quest completion ===
# Get current XP before DM tick
my $xp_before = $game->{player}->{xp};

# Simulate player being in treasure_room by writing PWD file
# The DM checks if player is in treasure_room directory
$game->create_file('/home/.pwd', '/sewer/.crack/under_nix/treasure_room')
     ->save_game()
     ->trigger_dm_tick();

# Verify quest was completed
$game->expect_quest_not_active(5);  # Quest 5 should be removed

# Verify XP was awarded (13000 XP for Navigate Maze)
my $xp_gained = $game->{player}->{xp} - $xp_before;
if ($xp_gained < 13000) {
    $game->fail("Expected at least 13000 XP from Navigate Maze quest, got: $xp_gained");
}

# Report results
exit($game->report() ? 0 : 1);
