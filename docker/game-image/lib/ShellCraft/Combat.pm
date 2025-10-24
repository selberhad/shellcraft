package Combat;
use strict;
use warnings;

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
    my $enemy_hp = -s $filepath;
    my $enemy_name = get_enemy_name($target);

    # Calculate damage based on player level
    my $damage = calc_damage($player->{level});

    if ($damage >= $enemy_hp) {
        # Enemy defeated
        unlink $filepath;
        print "You vanquished $enemy_name! (${enemy_hp} bytes)\n";
        print "+${enemy_hp} XP\n";
        $player->add_xp($enemy_hp);
    } else {
        # Damage enemy
        my $new_hp = $enemy_hp - $damage;
        truncate($filepath, $new_hp);

        print "You strike $enemy_name for $damage damage!\n";
        print "$enemy_name: ${new_hp}/${enemy_hp} bytes remaining\n";
        print "+${damage} XP\n";

        $player->add_xp($damage);
    }
}

# Calculate damage based on player level
sub calc_damage {
    my ($level) = @_;

    # Formula: base_damage * log2(level + 2)
    # This keeps damage scaling reasonable:
    # L0:  20 bytes
    # L1:  32 bytes
    # L5:  56 bytes
    # L10: 72 bytes
    # L20: 92 bytes

    my $base_damage = 20;
    my $scaling = log($level + 2) / log(2);

    return int($base_damage * $scaling);
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
