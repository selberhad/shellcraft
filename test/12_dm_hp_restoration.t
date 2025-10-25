#!/usr/bin/env perl
# Test: Dungeon Master HP Restoration
#
# Verifies:
# - DM restores player HP to full on every tick
# - HP restoration works at different levels
# - HP restoration respects max HP for level

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

my $game = GameTest->new(
    test_name => 'DM HP Restoration',
    verbose   => 1,
    save_path => '/tmp/test_hp_soul.dat',
);

print "\n=== HP Restoration at L0 ===\n";

# Create L0 player with damaged HP (50/100)
$game->start_fresh()
     ->expect_level(0)
     ->expect_max_hp(100)
     ->damage_player(50)
     ->expect_hp(50)
     ->save_game();

print "[TEST] Created L0 player with 50/100 HP\n";

# Run DM tick
run_dm_tick($game->{save_path});

# Verify HP restored to full
$game->load_save()
     ->expect_hp(100);

print "[TEST] ✓ HP restored from 50 to 100\n";

print "\n=== HP Restoration at L5 ===\n";

# Create L5 player with damaged HP (100/200)
$game->start_fresh()
     ->level_up_to(5)
     ->expect_level(5)
     ->expect_max_hp(200)
     ->damage_player(100)
     ->expect_hp(100)
     ->save_game();

print "[TEST] Created L5 player with 100/200 HP\n";

# Run DM tick
run_dm_tick($game->{save_path});

# Verify HP restored to full
$game->load_save()
     ->expect_hp(200);

print "[TEST] ✓ HP restored from 100 to 200\n";

print "\n=== HP Already Full (No-Op) ===\n";

# Create player with full HP
$game->start_fresh()
     ->expect_level(0)
     ->expect_hp(100)
     ->save_game();

print "[TEST] Created L0 player with 100/100 HP (full)\n";

# Run DM tick
run_dm_tick($game->{save_path});

# Verify HP still full
$game->load_save()
     ->expect_hp(100);

print "[TEST] ✓ HP remained at 100 (was already full)\n";

# Report
exit($game->report() ? 0 : 1);

# Helper
sub run_dm_tick {
    my ($soul_path) = @_;

    # Create a minimal test DM script
    my $test_dm = "/tmp/test_hp_dm_$$.pl";
    create_test_dm($test_dm, $soul_path);

    system("perl $test_dm --tick");
    unlink $test_dm;
}

sub create_test_dm {
    my ($script_path, $soul_path) = @_;

    # Just run the actual DM script with custom soul path
    # Note: This is a wrapper that sets up env and calls real DM
    open my $fh, '>', $script_path or die $!;
    print $fh <<'EODM';
#!/usr/bin/env perl
use strict;
use warnings;

# Set custom soul path and call real DM
$ENV{SOUL_PATH_OVERRIDE} = $ENV{TEST_SOUL_PATH};

# Load and execute the real dungeon-master
do '/usr/sbin/dungeon-master';
EODM
    close $fh;

    # Set env var for test DM
    $ENV{TEST_SOUL_PATH} = $soul_path;
}
