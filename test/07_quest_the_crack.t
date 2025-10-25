#!/usr/bin/env perl
# Test: L2 Quest - The Crack (Hidden Directory Discovery)
#
# Verifies:
# - Player at L2 has ls -a unlocked
# - .crack/ directory hidden in /sewer
# - Cannot see .crack/ without -a flag
# - Can cd into .crack/
# - Clue file exists inside

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

# Create test
# NOTE: Must use /home/soul.dat because DM hardcodes this path
my $game = GameTest->new(
    test_name => 'L2 Quest: The Crack',
    verbose   => 1,
    save_path => '/home/soul.dat',
);

# Start at L0, level up to L2
$game->start_fresh()
     ->expect_level(0)
     ->expect_cannot_use('ls -a');  # L0 doesn't have ls -a

# Level up to L1
$game->add_xp(1000)  # L0->L1 requires 1000 XP (fib(2) * 1000 = 1 * 1000)
     ->expect_level(1)
     ->expect_can_use('ls -s')    # L1 unlocks ls -s
     ->expect_cannot_use('ls -a');  # ls -a not unlocked until L2

# Level up to L2 - unlocks ls -a for hidden file discovery
$game->level_up_once()  # Should go L1 -> L2
     ->expect_level(2)
     ->expect_can_use('ls -a')  # L2 unlocks ls -a
     ->add_quest(2)              # Add "The Crack" quest (ID=2)
     ->expect_quest_active(2);

# Test 1: .crack/ directory is hidden (not visible with plain ls)
my $ls_output = $game->get_command_output('ls /sewer');
die "ERROR: .crack should be hidden without -a flag" if $ls_output =~ /\.crack/;
$game->log("✓ .crack/ is hidden from plain ls");

# Test 2: .crack/ directory visible with ls -a
my $ls_a_output = $game->get_command_output('ls -a /sewer');
die "ERROR: .crack should be visible with -a flag" unless $ls_a_output =~ /\.crack/;
$game->log("✓ .crack/ visible with ls -a");

# Test 3: Can cd into .crack/ directory
$game->expect_dir_exists('/sewer/.crack');

# Test 4: Clue file exists inside .crack/
$game->expect_file_exists('/sewer/.crack/.clue')
     ->expect_file_contains('/sewer/.crack/.clue', 'crack');  # Should mention "crack"

# Test 5: Quest completion - DM awards XP when player is IN .crack/
# Simulate player being in .crack/ by writing PWD file
$game->create_file('/home/.pwd', '/sewer/.crack')
     ->save_game()
     ->trigger_dm_tick();  # DM checks PWD and awards 2000 XP

# Quest should be completed
$game->expect_quest_not_active(2)  # Quest 2 should be removed
     ->expect_xp_at_least(2000);    # Should have gained 2000 XP from quest

# Report results
exit($game->report() ? 0 : 1);
