#!/usr/bin/env perl
use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use Player;
use Commands;

# Dungeon Master - Root cron process that orchestrates the game world
# Runs every minute via root crontab
#
# Responsibilities:
# 1. Check quest completion conditions
# 2. Award quest XP and remove completed quests
# 3. Repopulate monsters (rats, etc.)
# 4. Apply environmental effects
#
# Usage:
#   dungeon-master           # Normal cron mode (runs tick)
#   dungeon-master --tick    # Explicit tick (for testing)

# Configuration
my $SOUL_PATH = '/home/soul.dat';
my $SEWER_PATH = '/sewer';
my $RAT_REPOP_CHANCE = 0.25;  # 25% chance per tick
my $MAX_RATS = 5;

# Quest definitions
my $QUEST_SEWER_CLEANSE = 1;
my $QUEST_THE_CRACK = 2;
my $QUEST_LOCKED_DOOR = 3;
my $QUEST_PORTAL_HOME = 4;
my $QUEST_NAVIGATE_MAZE = 5;

# Quest rewards (should grant full XP to reach next level)
my $QUEST_SEWER_XP = 1000;   # L0->L1 requires 1000 XP
my $QUEST_CRACK_XP = 2000;   # L1->L2 requires 2000 XP
my $QUEST_DOOR_XP = 3000;    # L2->L3 requires 3000 XP
my $QUEST_PORTAL_XP = 8000;  # L4->L5 requires 8000 XP
my $QUEST_MAZE_XP = 13000;   # L5->L6 requires 13000 XP

# Main tick - run if called directly or with --tick
my $should_tick = (@ARGV == 0) || ($ARGV[0] eq '--tick');
main() if $should_tick;

sub main {
    # Check for door transformation (L3 quest) - must happen FIRST
    check_door_transformation();

    # Load player soul AFTER transformations (so quest checks see current state)
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
                $player->add_xp($QUEST_SEWER_XP);
                $player->remove_quest($QUEST_SEWER_CLEANSE);
                $awarded_xp += $QUEST_SEWER_XP;
            }
        }
        elsif ($quest_id == $QUEST_THE_CRACK) {
            # Check if player is currently in .crack/ directory
            my $pwd = read_player_pwd();
            if ($pwd && $pwd =~ m{/\.crack$}) {
                $player->add_xp($QUEST_CRACK_XP);
                $player->remove_quest($QUEST_THE_CRACK);
                $awarded_xp += $QUEST_CRACK_XP;
            }
        }
        elsif ($quest_id == $QUEST_LOCKED_DOOR) {
            # Check if under_nix directory exists (door has been unlocked)
            if (-d '/sewer/.crack/under_nix') {
                $player->add_xp($QUEST_DOOR_XP);
                $player->remove_quest($QUEST_LOCKED_DOOR);
                $awarded_xp += $QUEST_DOOR_XP;
            }
        }
        elsif ($quest_id == $QUEST_PORTAL_HOME) {
            # Check if portal symlink exists
            if (-l '/home/portal') {
                my $target = readlink('/home/portal');
                if ($target && $target =~ /under_nix/) {
                    $player->add_xp($QUEST_PORTAL_XP);
                    $player->remove_quest($QUEST_PORTAL_HOME);
                    $awarded_xp += $QUEST_PORTAL_XP;
                }
            }
        }
        elsif ($quest_id == $QUEST_NAVIGATE_MAZE) {
            # Check if player has navigated to the treasure room
            # Player must cd into treasure_room to complete the quest
            my $pwd = read_player_pwd();
            if ($pwd && $pwd =~ m{treasure_room}) {
                $player->add_xp($QUEST_MAZE_XP);
                $player->remove_quest($QUEST_NAVIGATE_MAZE);
                $awarded_xp += $QUEST_MAZE_XP;
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

# Create symlink maze structure in under_nix
# Maze has circular/confusing symlinks for L4 discovery
# Solvable path for L6 with ls -l
sub create_symlink_maze {
    my ($base_path) = @_;

    # Create rooms for the maze
    mkdir "$base_path/entrance", 0755;
    mkdir "$base_path/left_path", 0755;
    mkdir "$base_path/right_path", 0755;
    mkdir "$base_path/center_hall", 0755;
    mkdir "$base_path/dead_end", 0755;
    mkdir "$base_path/treasure_room", 0755;

    # Create symlinks - some circular, some pointing to solution
    # Entrance has three choices
    symlink '../left_path', "$base_path/entrance/left";
    symlink '../right_path', "$base_path/entrance/right";
    symlink '../center_hall', "$base_path/entrance/forward";

    # Left path is a dead end with circular link
    symlink '../entrance', "$base_path/left_path/back";
    symlink '../left_path', "$base_path/left_path/forward";  # Circular!

    # Right path also circular
    symlink '../entrance', "$base_path/right_path/back";
    symlink '../dead_end', "$base_path/right_path/forward";

    # Dead end loops back
    symlink '../right_path', "$base_path/dead_end/back";
    symlink '../dead_end', "$base_path/dead_end/forward";  # Circular!

    # Center hall is the CORRECT path to treasure
    symlink '../entrance', "$base_path/center_hall/back";
    symlink '../treasure_room', "$base_path/center_hall/forward";  # Solution!

    # Treasure room - final destination
    symlink '../center_hall', "$base_path/treasure_room/back";

    # Place treasure file
    open my $fh, '>', "$base_path/treasure_room/treasure" or return;
    print $fh "Congratulations! You have navigated the maze.\n\n";
    print $fh "You found the treasure hidden in Under-Nix.\n";
    print $fh "The Wyrm's labyrinth has been conquered.\n";
    close $fh;
}

# L3 Quest: Door Transformation
# Check if player has created a key file in .crack/
# If so, transform locked_door into under_nix/ directory
sub check_door_transformation {
    my $crack_path = '/sewer/.crack';
    my $key_file = "$crack_path/key";
    my $door_file = "$crack_path/locked_door";
    my $under_nix_path = "$crack_path/under_nix";

    # Check if key exists and door hasn't been transformed yet
    if (-f $key_file && -f $door_file) {
        # Remove the locked door
        unlink $door_file;

        # Create under_nix directory
        mkdir $under_nix_path, 0755;

        # Create symlink maze structure (L4-L6 quests)
        create_symlink_maze($under_nix_path);

        # Add a welcome message
        open my $fh, '>', "$under_nix_path/README.txt" or return;
        print $fh "You have entered Under-Nix, the realm beneath the sewers.\n\n";
        print $fh "The path ahead is treacherous and confusing.\n";
        print $fh "You will need better tools to navigate these passages.\n";
        close $fh;

        # Consume the key (it's used up)
        unlink $key_file;
    }
}

sub read_player_pwd {
    my $pwd_file = '/home/.pwd';

    return undef unless -f $pwd_file;

    if (open my $fh, '<', $pwd_file) {
        my $pwd = <$fh>;
        close $fh;
        chomp $pwd if defined $pwd;
        return $pwd;
    }

    return undef;
}
