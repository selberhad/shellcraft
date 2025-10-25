#!/usr/bin/env perl
# Test: Basic combat mechanics
#
# Verifies:
# - Level 0 player can defeat a small rat
# - Player takes expected damage
# - XP is awarded correctly
# - Level up occurs when expected

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

# Create test
my $game = GameTest->new(
    test_name => 'Basic Combat',
    verbose   => 1,
    save_path => '/tmp/test_basic_combat.dat',
);

# Start fresh, level 0
$game->start_fresh()
     ->expect_level(0)
     ->expect_hp_at_least(100)
     ->expect_can_use('ls')
     ->expect_cannot_use('ls -l');

# Fight a small rat (100 bytes)
# L0 player: 20 damage, rat does 12 damage
# Expected: 5 turns, player takes 60 damage
$game->fight('/tmp/test_rat.rat')
     ->expect_level(1)           # 100 XP should level us up
     ->expect_hp_at_least(100)   # HP restored on level up
     ->expect_can_use('ls -l')   # Now have ls -l unlocked
     ->save_or_die();

# Report results
exit($game->report() ? 0 : 1);
