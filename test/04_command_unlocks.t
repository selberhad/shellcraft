#!/usr/bin/env perl
# Test: Command unlock validation
#
# Verifies the command validation fix:
# - Base commands work at L0
# - Flags are blocked until unlocked
# - Arguments (filenames) work with base commands

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

my $game = GameTest->new(
    test_name => 'Command Unlock Validation',
    verbose   => 1,
);

# Level 0 tests
$game->start_fresh()
     ->expect_level(0)
     ->expect_can_use('ls')           # Base command OK
     ->expect_can_use('ls /home')     # With filename OK
     ->expect_cannot_use('ls -l')     # Flag blocked (unlocked at L6)
     ->expect_cannot_use('ls -a')     # Flag blocked (unlocked at L2)
     ->expect_cannot_use('grep')      # Not unlocked yet (L11)
     ->expect_cannot_use('grep -i');  # Definitely not

# Level up to 1 (ls -s unlocked)
$game->level_up_once()
     ->expect_level(1)
     ->expect_can_use('ls -s')        # Now unlocked!
     ->expect_can_use('ls -s /home')  # Flag + filename OK
     ->expect_cannot_use('ls -l')     # Still locked (L6)
     ->expect_cannot_use('ls -a')     # Still locked (L2)
     ->expect_cannot_use('grep');     # Still locked

# Level up to 2 (ls -a unlocked)
$game->level_up_once()
     ->expect_level(2)
     ->expect_can_use('ls -a')        # Now unlocked!
     ->expect_can_use('ls -a /home')  # With path
     ->expect_cannot_use('ls -l')     # Still locked (L6)
     ->expect_cannot_use('grep');     # Still locked

# Level up to 11 (grep unlocked) - level up 9 more times
for (1..9) { $game->level_up_once(); }
$game->expect_level(11)
     ->expect_can_use('grep')         # Base grep OK
     ->expect_can_use('grep pattern file')  # With args OK
     ->expect_cannot_use('grep -i')   # Flag still locked (L12)
     ->expect_cannot_use('grep -n');

# Level up to 12 (grep flags unlocked)
$game->level_up_once()
     ->expect_level(12)
     ->expect_can_use('grep -i')      # Now unlocked
     ->expect_can_use('grep -n')      # Also unlocked
     ->expect_can_use('grep -i pattern file');  # Flag + args OK

exit($game->report() ? 0 : 1);
