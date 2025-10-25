#!/usr/bin/env perl
# Test: Quest System
#
# Verifies:
# - Quest slot unlocking (1 at L0, +1 every 6 levels)
# - Quest acceptance and tracking
# - Quest removal
# - Cannot accept duplicate quests
# - Quest slot limits enforced
#
# NOTE: This tests the Player.pm quest API directly.
# The Dungeon Master quest completion is tested separately
# in an integration test.

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

my $game = GameTest->new(
    test_name => 'Quest System',
    verbose   => 1,
    save_path => '/tmp/test_quest.dat',
);

# Quest IDs
my $QUEST_SEWER = 1;
my $QUEST_CRYPT = 2;
my $QUEST_TOWER = 3;

print "\n=== Quest Slot Unlocking ===\n";

# L0: 1 quest slot
$game->start_fresh()
     ->expect_level(0)
     ->expect_quest_slots(1);

# L5: Still 1 slot
$game->set_stats(level => 5)
     ->expect_quest_slots(1);

# L6: 2 slots
$game->set_stats(level => 6)
     ->expect_quest_slots(2);

# L12: 3 slots
$game->set_stats(level => 12)
     ->expect_quest_slots(3);

# L42: 8 slots (max)
$game->set_stats(level => 42)
     ->expect_quest_slots(8);

print "\n=== Quest Acceptance ===\n";

# Reset to L0 for quest testing
$game->set_stats(level => 0, xp => 0, hp => 100);

# Add first quest
$game->add_quest($QUEST_SEWER)
     ->expect_quest_active($QUEST_SEWER)
     ->expect_quest_not_active($QUEST_CRYPT);

# Cannot add duplicate
$game->add_quest($QUEST_SEWER)
     ->expect_quest_active($QUEST_SEWER);

# Cannot add second quest (only 1 slot at L0)
$game->add_quest($QUEST_CRYPT)
     ->expect_quest_not_active($QUEST_CRYPT);

print "\n=== Quest Removal ===\n";

# Remove quest
$game->remove_quest($QUEST_SEWER)
     ->expect_quest_not_active($QUEST_SEWER);

# Now can add different quest
$game->add_quest($QUEST_CRYPT)
     ->expect_quest_active($QUEST_CRYPT)
     ->expect_quest_not_active($QUEST_SEWER);

print "\n=== Multiple Quest Slots ===\n";

# Level up to L6 (2 slots)
$game->set_stats(level => 6)
     ->expect_quest_slots(2);

# Already have QUEST_CRYPT, add another
$game->add_quest($QUEST_SEWER)
     ->expect_quest_active($QUEST_CRYPT)
     ->expect_quest_active($QUEST_SEWER);

# Cannot add third (only 2 slots)
$game->add_quest($QUEST_TOWER)
     ->expect_quest_not_active($QUEST_TOWER);

# Remove one, can add third
$game->remove_quest($QUEST_CRYPT)
     ->expect_quest_not_active($QUEST_CRYPT)
     ->add_quest($QUEST_TOWER)
     ->expect_quest_active($QUEST_TOWER)
     ->expect_quest_active($QUEST_SEWER);

print "\n=== Save/Load with Quests ===\n";

# Save with active quests
$game->save_game();

# Load and verify quests persist
$game->load_save()
     ->expect_quest_active($QUEST_SEWER)
     ->expect_quest_active($QUEST_TOWER)
     ->expect_quest_not_active($QUEST_CRYPT);

# Report
exit($game->report() ? 0 : 1);
