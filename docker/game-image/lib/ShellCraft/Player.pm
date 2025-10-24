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
        last_activity => time(),
    };

    return bless $self, $class;
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

# Load player from spellbook.dat
sub load {
    my ($class, $save_path) = @_;

    open my $fh, '<', $save_path or return $class->new();
    binmode $fh;

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

    my $player = $class->new(
        level => $level,
        xp    => $xp,
    );

    return $player;
}

# Save player to spellbook.dat
sub save {
    my ($self, $save_path) = @_;
    $save_path ||= '/home/spellbook.dat';

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

    # Write player data
    print $fh pack('LL', $self->{level}, $self->{xp});

    # Padding to align
    print $fh pack('x16');

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

    print "\n";
    print "*** LEVEL UP! ***\n";
    print "You are now level $self->{level}!\n";

    # Show what was unlocked
    my $unlock = Commands::unlock_at_level($self->{level});
    if ($unlock) {
        print "You have unlocked: $unlock\n";
    }

    print "\n";
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
