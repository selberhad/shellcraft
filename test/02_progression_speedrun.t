#!/usr/bin/env perl
# Test: Progression Speedrun
#
# Simulates a "speedrun" from L0 to L6
# Verifies progression curve and unlock order

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

my $game = GameTest->new(
    test_name => 'Progression Speedrun (L0→L6)',
    verbose   => 1,
);

# Level 0 → 1 (100 XP needed)
$game->start_fresh()
     ->expect_level(0)
     ->fight('/tmp/rat1.rat')     # 100 bytes
     ->expect_level(1)
     ->expect_can_use('ls -l');

# Level 1 → 2 (150 XP needed)
$game->fight('/tmp/rat2.rat')     # 150 bytes
     ->expect_level(2)
     ->expect_can_use('mv')
     ->expect_can_use('cp');

# Level 2 → 3 (225 XP needed)
$game->fight('/tmp/rat3.rat')     # 250 bytes (overkill)
     ->expect_level(3)
     ->expect_can_use('rmdir');

# Level 3 → 4 (338 XP needed)
$game->fight('/tmp/rat4.rat')     # 400 bytes
     ->expect_level(4)
     ->expect_can_use('file')
     ->expect_can_use('wc');

# Level 4 → 6 (400 XP rat gives enough to skip L5)
$game->fight('/tmp/rat_large.rat')  # 400 bytes
     ->expect_level(6)
     ->expect_can_use('head')
     ->expect_can_use('tail')
     ->expect_can_use('grep')  # L6 unlock
     ->expect_alive()
     ->save_or_die();

# Report
print "\nProgression Summary:\n";
print "  Final Level: " . $game->{player}{level} . "\n";
print "  Final HP:    " . $game->{player}{hp} . "/" . $game->{player}->max_hp() . "\n";
print "  Total XP:    " . $game->{player}{xp} . "\n";
print "\n";

exit($game->report() ? 0 : 1);
