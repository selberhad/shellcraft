#!/usr/bin/env perl
# Test: L5 Quest - Portal Home
#
# Phase 8.a: Symlink Creation Test
#
# Verifies:
# - Player at L5 has ln -s unlocked
# - Can create symlink from /home to under_nix
# - Symlink works (cd /home/portal takes you to under_nix)
# - DM awards Portal Home quest XP
# - Quest is removed from active quests

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

# Create test
my $game = GameTest->new(
    test_name => 'L5 Quest: Portal Home',
    verbose   => 1,
    save_path => '/home/soul.dat',
);

# === Setup: Create player and unlock under_nix ===

# Start fresh and level to L5
$game->start_fresh()
     ->expect_level(0);

# Level through L0 -> L5
$game->add_xp(1000)       # L0 -> L1
     ->level_up_once()    # L1 -> L2
     ->level_up_once()    # L2 -> L3
     ->level_up_once()    # L3 -> L4
     ->level_up_once()    # L4 -> L5
     ->expect_level(5)
     ->expect_can_use('ln -s');  # L5 should have ln -s unlocked

# Create under_nix by using key (prerequisite)
$game->run_command('touch /sewer/.crack/key')
     ->save_game()
     ->trigger_dm_tick()
     ->expect_dir_exists('/sewer/.crack/under_nix');

# Add Portal Home quest (ID=4)
$game->add_quest(4)
     ->expect_quest_active(4);

# === Test 1: Create symlink portal ===
$game->run_command('ln -s /sewer/.crack/under_nix /home/portal')
     ->expect_command_success('test -L /home/portal');  # Verify symlink exists

# === Test 2: Verify symlink points to correct target ===
my $link_target = $game->get_command_output('readlink /home/portal');
if ($link_target !~ /under_nix/) {
    $game->fail("Symlink should point to under_nix, got: $link_target");
}

# === Test 3: Verify symlink works (can navigate through it) ===
# Verify we can access under_nix files through the portal
my $portal_ls = $game->get_command_output('ls /home/portal');
if ($portal_ls !~ /(entrance|README)/) {
    $game->fail("Expected to see under_nix contents through portal, got: $portal_ls");
}

# === Test 4: DM quest completion ===
# Get current XP before DM tick
my $xp_before = $game->{player}->{xp};

# Save and trigger DM tick - should complete Portal Home quest
$game->save_game()
     ->trigger_dm_tick();

# Verify quest was completed
$game->expect_quest_not_active(4);  # Quest 4 should be removed

# Verify XP was awarded (8000 XP for Portal Home)
my $xp_gained = $game->{player}->{xp} - $xp_before;
if ($xp_gained < 8000) {
    $game->fail("Expected at least 8000 XP from Portal Home quest, got: $xp_gained");
}

# Report results
exit($game->report() ? 0 : 1);
