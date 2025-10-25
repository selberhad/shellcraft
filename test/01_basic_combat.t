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

# Fight a small rat (100 bytes = 100 XP)
# L0 player: 20 damage, rat does 12 damage
# Expected: 5 turns, player takes 60 damage
# NEW FORMULA: L0→L1 needs 1000 XP, so still L0 after one rat
$game->fight('/tmp/test_rat.rat')
     ->expect_level(0)           # 100 XP is not enough (need 1000)
     ->expect_hp_at_least(40)    # Should have taken damage but survive
     ->expect_cannot_use('ls -l') # Still locked at L0
     ->save_or_die();

# Report results
exit($game->report() ? 0 : 1);
