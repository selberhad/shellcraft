#!/usr/bin/env perl
# Test: Permadeath mechanics
#
# Verifies:
# - Low-level player dies against strong enemy
# - Save file is deleted on death
# - Death detection works correctly

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

my $game = GameTest->new(
    test_name => 'Permadeath Test',
    verbose   => 1,
);

# Start fresh L0 player (100 HP)
$game->start_fresh()
     ->expect_level(0)
     ->expect_hp_at_least(100);

# Set low HP to guarantee death
$game->set_stats(hp => 20);

# Fight a big enemy (daemon = 1200 bytes, 34 damage)
# Player will die on first hit
$game->fight('/tmp/daemon_test.rat')
     ->expect_dead()
     ->save_or_die();

# Verify save was deleted
my $save_exists = -f $game->{save_path};
if ($save_exists) {
    print "[FAIL] Save file should be deleted on death!\n";
    $game->{failures}++;
} else {
    print "[TEST] ✓ Save file deleted on death\n";
}

exit($game->report() ? 0 : 1);
