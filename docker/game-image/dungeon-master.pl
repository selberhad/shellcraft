#!/usr/bin/env perl
use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use Player;

# Dungeon Master - Root cron process that orchestrates the game world
# Runs every minute via root crontab
#
# Responsibilities:
# 1. Check quest completion conditions
# 2. Award quest XP and remove completed quests
# 3. Repopulate monsters (rats, etc.)
# 4. Apply environmental effects

# Configuration
my $SOUL_PATH = '/home/soul.dat';
my $SEWER_PATH = '/sewer';
my $RAT_REPOP_CHANCE = 0.25;  # 25% chance per tick
my $MAX_RATS = 5;

# Quest definitions
my $QUEST_SEWER_CLEANSE = 1;
my $QUEST_SEWER_XP = 500;

# Main tick
main();

sub main {
    # Load player soul (read-only for quest checks)
    my $player = Player->load_or_create($SOUL_PATH);

    # Check quest completions and award XP
    check_quests($player);

    # Repopulate world
    repopulate_rats();

    # Future: other DM activities (environmental effects, random events, etc.)
}

sub check_quests {
    my ($player) = @_;

    my @active_quests = $player->active_quests();
    my $awarded_xp = 0;

    for my $quest_id (@active_quests) {
        if ($quest_id == $QUEST_SEWER_CLEANSE) {
            # Check if all rats are dead
            my $rat_count = count_rats();
            if ($rat_count == 0) {
                # Quest complete! Award XP and remove quest
                $player->add_xp($QUEST_SEWER_XP);
                $player->remove_quest($QUEST_SEWER_CLEANSE);
                $awarded_xp += $QUEST_SEWER_XP;
            }
        }
    }

    # Save soul if we awarded any XP
    if ($awarded_xp > 0) {
        $player->save();
    }
}

sub repopulate_rats {
    my $current_count = count_rats();

    # Don't exceed max rats
    return if $current_count >= $MAX_RATS;

    # Roll for respawn (25% chance)
    return unless rand() < $RAT_REPOP_CHANCE;

    # Spawn one rat
    spawn_rat();
}

sub count_rats {
    opendir(my $dh, $SEWER_PATH) or return 0;
    my @rats = grep { /\.rat$/ } readdir($dh);
    closedir($dh);
    return scalar @rats;
}

sub spawn_rat {
    my $current_count = count_rats();
    my $next_id = $current_count + 1;

    # Generate random rat HP (100-500 bytes)
    my $rat_hp = 100 + int(rand(401));

    my $rat_file = "$SEWER_PATH/rat_$next_id.rat";

    # Create rat file with random bytes
    open my $fh, '>', $rat_file or die "Cannot create rat: $!";
    binmode $fh;

    # Write random bytes for HP
    for (1..$rat_hp) {
        print $fh chr(int(rand(256)));
    }

    close $fh;
}
