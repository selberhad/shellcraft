package Combat;
use strict;
use warnings;
use Time::HiRes qw(sleep);

# Combat delay helper - respects SHELLCRAFT_NO_DELAY for tests
sub combat_sleep {
    my ($seconds) = @_;
    return if $ENV{SHELLCRAFT_NO_DELAY};
    sleep($seconds);
}

# Handle combat when player attacks an enemy file
sub handle_combat {
    my ($player, $target) = @_;

    # Resolve full path
    my $filepath = resolve_path($target);

    unless (-f $filepath) {
        print "No such enemy: $target\n";
        return;
    }

    # Get current enemy HP (file size in bytes)
    my $enemy_max_hp = -s $filepath;
    my $enemy_hp = $enemy_max_hp;
    my $enemy_name = get_enemy_name($target);

    print "\n";
    print "You engage $enemy_name in combat!\n";
    combat_sleep(1);

    # Combat loop - alternating turns
    while (1) {
        # Player's turn
        print "\n";
        print "You swing at $enemy_name...\n";
        combat_sleep(1);

        my $player_damage = calc_player_damage($player->{level});
        print "You strike $enemy_name for $player_damage damage!\n";
        $enemy_hp -= $player_damage;

        combat_sleep(1);

        if ($enemy_hp <= 0) {
            # Enemy defeated!
            my $deleted = unlink $filepath;
            if (!$deleted) {
                warn "WARNING: Failed to delete enemy file: $filepath (error: $!)\n";
            }
            print "\n";
            print "*** $enemy_name has been vanquished! ***\n";
            print "+${enemy_max_hp} XP\n";
            $player->add_xp($enemy_max_hp);

            # Restore HP to full on victory
            my $old_hp = $player->{hp};
            my $max_hp = $player->max_hp();
            $player->{hp} = $max_hp;

            if ($old_hp < $max_hp) {
                my $healed = $max_hp - $old_hp;
                print "HP restored to full! (+$healed HP)\n";
            }

            $player->save();
            return;
        }

        # Show enemy HP
        print "$enemy_name: ${enemy_hp}/${enemy_max_hp} bytes remaining\n";
        combat_sleep(1);

        # Enemy's turn
        print "\n";
        print "$enemy_name strikes back!\n";
        combat_sleep(1);

        my $enemy_damage = calc_enemy_damage($enemy_max_hp);
        print "$enemy_name hits you for $enemy_damage damage!\n";

        my $new_hp = $player->take_damage($enemy_damage);
        print "Your HP: ${new_hp}/" . $player->max_hp() . "\n";

        combat_sleep(1);

        if ($player->is_dead()) {
            # Player died!
            handle_death($player);
            return;
        }

        # Damage the enemy file to reflect remaining HP
        truncate($filepath, $enemy_hp);

        # Save player state (HP changes)
        $player->save();
    }
}

# Calculate player damage based on level
sub calc_player_damage {
    my ($level) = @_;

    # Formula: Roll 10 dice, each with <base_damage> sides
    # Base damage scales with level using log2:
    # L0:  10d20 (avg 105, range 10-200)
    # L1:  10d32 (avg 165, range 10-320)
    # L5:  10d56 (avg 285, range 10-560)
    # L10: 10d72 (avg 365, range 10-720)
    # L20: 10d92 (avg 465, range 10-920)

    my $base_damage = 20;
    my $scaling = log($level + 2) / log(2);
    my $die_size = int($base_damage * $scaling);

    # Roll 10 dice with $die_size sides each
    my $total_damage = 0;
    for (1..10) {
        $total_damage += 1 + int(rand($die_size));
    }

    return $total_damage;
}

# Calculate enemy damage based on enemy max HP (difficulty)
sub calc_enemy_damage {
    my ($enemy_max_hp) = @_;

    # Stronger enemies hit harder
    # Formula: 10 + (enemy_hp / 50)
    # Rat (100-500 bytes): 12-20 damage
    # Skeleton (800 bytes): 26 damage
    # Daemon (1200 bytes): 34 damage

    my $damage = 10 + int($enemy_max_hp / 50);

    return $damage;
}

# Handle player death
sub handle_death {
    my ($player) = @_;

    print "\n";
    print "======================================\n";
    print "        YOU HAVE DIED                 \n";
    print "======================================\n";
    print "\n";
    print "Your soul dissipates into the void...\n";
    print "All progress has been lost.\n";
    print "\n";

    # Delete the save file (like the telomeres being destroyed)
    unlink '/home/soul.dat';

    # Exit the game
    exit(0);
}

# Resolve path to enemy file
sub resolve_path {
    my ($path) = @_;

    # If absolute path, use as-is
    return $path if $path =~ m{^/};

    # If relative, check common enemy locations
    for my $dir ('/sewer', '/crypt', '/tower', '.') {
        my $fullpath = "$dir/$path";
        return $fullpath if -f $fullpath;
    }

    return $path;
}

# Get enemy display name
sub get_enemy_name {
    my ($path) = @_;

    # Extract filename
    my $name = $path;
    $name =~ s{.*/}{};  # Remove directory
    $name =~ s/\.\w+$//;  # Remove extension

    # Prettify
    $name =~ s/_/ /g;
    $name = ucfirst($name);

    # Add article
    if ($name =~ /^[aeiou]/i) {
        return "an $name";
    } else {
        return "a $name";
    }
}

1;
