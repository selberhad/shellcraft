#!/usr/bin/env perl
# Test: Progression Speedrun
#
# Simulates a "speedrun" from L0 to L5
# Verifies progression curve and unlock order
#
# XP FORMULA: fibonacci(level + 1) * 1000

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

my $game = GameTest->new(
    test_name => 'Progression Speedrun (L0→L5)',
    verbose   => 1,
);

# Test progression through levels using level_up_once helper
$game->start_fresh()
     ->expect_level(0);

# L0 → L1 (unlock ls -s for file sizes)
$game->level_up_once()
     ->expect_level(1)
     ->expect_can_use('ls -s');

# L1 → L2 (unlock ls -a for hidden files)
$game->level_up_once()
     ->expect_level(2)
     ->expect_can_use('ls -a');

# L2 → L3 (unlock touch to create files)
$game->level_up_once()
     ->expect_level(3)
     ->expect_can_use('touch');

# L3 → L4 (unlock ls -R for recursive listing)
$game->level_up_once()
     ->expect_level(4)
     ->expect_can_use('ls -R');

# L4 → L5 (unlock ln for symlinks)
$game->level_up_once()
     ->expect_level(5)
     ->expect_can_use('ln')
     ->expect_can_use('ln -s')
     ->expect_alive()
     ->save_or_die();

# Report
print "\nProgression Summary:\n";
print "  Final Level: " . $game->{player}{level} . "\n";
print "  Final HP:    " . $game->{player}{hp} . "/" . $game->{player}->max_hp() . "\n";
print "  Total XP:    " . $game->{player}{xp} . "\n";
print "\n";

exit($game->report() ? 0 : 1);
