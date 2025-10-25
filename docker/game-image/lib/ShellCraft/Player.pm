package Player;
use strict;
use warnings;

# Player object constructor
sub new {
    my ($class, %args) = @_;

    my $self = {
        name          => $args{name} || 'Adventurer',
        level         => $args{level} || 0,
        xp            => $args{xp} || 0,
        hp            => $args{hp} // $class->max_hp(0),  # Default to max HP for level 0
        last_activity => time(),
    };

    return bless $self, $class;
}

# Calculate max HP based on level
sub max_hp {
    my ($class_or_self, $level) = @_;

    # If called as instance method, use self's level
    if (ref $class_or_self) {
        $level = $class_or_self->{level};
    }

    # Formula: 100 + (level * 20)
    # L0: 100 HP, L1: 120 HP, L5: 200 HP, L10: 300 HP, L20: 500 HP
    return 100 + ($level * 20);
}

# Load save file or create new player
sub load_or_create {
    my ($class, $save_path) = @_;

    if (-f $save_path) {
        return $class->load($save_path);
    } else {
        my $player = $class->new();
        $player->save($save_path);
        return $player;
    }
}

# Load player from soul.dat
sub load {
    my ($class, $save_path) = @_;

    open my $fh, '<', $save_path or return $class->new();
    binmode $fh;

    # Get file size - HP is encoded as file size!
    my $file_size = -s $save_path;

    # Read magic header
    my $magic;
    read($fh, $magic, 4);

    # Verify magic bytes
    unless ($magic eq 'SHC!') {
        warn "Invalid save file: bad magic bytes\n";
        close $fh;
        return $class->new();
    }

    # Read version
    my $version_bytes;
    read($fh, $version_bytes, 2);
    my $version = unpack('S', $version_bytes);

    # Read player data (simple format for v0.1)
    my $data;
    read($fh, $data, 16);
    my ($level, $xp) = unpack('LL', $data);

    close $fh;

    # HP is the "telomere" - the file size minus the header (30 bytes)
    # Header: 4 (magic) + 2 (version) + 8 (checksum) + 8 (LL pack: level+xp) + 8 (padding) = 30 bytes
    my $header_size = 30;
    my $hp = $file_size - $header_size;

    # Clamp HP to max for level (in case of corruption)
    my $max_hp = $class->max_hp($level);
    $hp = $max_hp if $hp > $max_hp;
    $hp = 0 if $hp < 0;

    my $player = $class->new(
        level => $level,
        xp    => $xp,
        hp    => $hp,
    );

    return $player;
}

# Save player to soul.dat
sub save {
    my ($self, $save_path) = @_;
    $save_path ||= '/home/soul.dat';

    open my $fh, '>', $save_path or do {
        warn "Failed to save: $!\n";
        return;
    };
    binmode $fh;

    # Write magic header
    print $fh 'SHC!';

    # Write version (1)
    print $fh pack('S', 1);

    # Write checksum placeholder (8 bytes)
    print $fh pack('Q', 0);

    # Write player data (level and xp)
    print $fh pack('LL', $self->{level}, $self->{xp});

    # Padding to align (8 bytes)
    print $fh pack('x8');

    # Write HP as "telomeres" - null bytes padding
    # This makes HP visible as file size!
    my $hp = $self->{hp} || 0;
    print $fh pack("x$hp") if $hp > 0;

    close $fh;

    return 1;
}

# Add XP and check for level up
sub add_xp {
    my ($self, $amount) = @_;

    $self->{xp} += $amount;

    # Check for level up
    while ($self->{xp} >= $self->xp_for_next_level()) {
        $self->level_up();
    }
}

# Level up the player
sub level_up {
    my ($self) = @_;

    $self->{level}++;

    # Restore HP to new max on level up
    $self->{hp} = $self->max_hp();

    print "\n";
    print "*** LEVEL UP! ***\n";
    print "You are now level $self->{level}!\n";
    print "HP restored to " . $self->{hp} . "!\n";

    # Show what was unlocked
    my $unlock = Commands::unlock_at_level($self->{level});
    if ($unlock) {
        print "You have unlocked: $unlock\n";
    }

    print "\n";
}

# Take damage
sub take_damage {
    my ($self, $amount) = @_;

    $self->{hp} -= $amount;
    $self->{hp} = 0 if $self->{hp} < 0;

    return $self->{hp};
}

# Check if player is dead
sub is_dead {
    my ($self) = @_;
    return $self->{hp} <= 0;
}

# Calculate XP needed for next level
sub xp_for_next_level {
    my ($self) = @_;

    # Formula: 100 * (1.5 ^ level)
    # This gives reasonable progression:
    # L0->L1: 100 XP
    # L1->L2: 150 XP
    # L2->L3: 225 XP
    # L10->L11: 5766 XP

    return int(100 * (1.5 ** $self->{level}));
}

1;
