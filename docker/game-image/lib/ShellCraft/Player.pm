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

    # Read player data
    my $data;
    read($fh, $data, 12);
    my ($level, $xp) = unpack('LQ<', $data);

    # Skip quest slots (32 bytes) and padding (4 bytes) for now
    seek($fh, 36, 1);  # Skip forward 36 bytes

    close $fh;

    # HP is the "telomere" - the file size minus the header
    # Header: 4 (magic) + 2 (version) + 8 (checksum) + 4 (level) + 8 (xp) + 32 (quests) + 4 (padding) = 62 bytes
    my $header_size = 62;
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
    print $fh pack('LQ<', $self->{level}, $self->{xp});

    # Write quest slots (8 x u32 = 32 bytes)
    my @quests = (0) x 8;  # Default: all empty
    print $fh pack('L8', @quests);

    # Padding to align (4 bytes)
    print $fh pack('x4');

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

    # Formula: fibonacci(level + 2) * 1000
    # This gives natural progression that scales nicely:
    # L0->L1: 1000 XP (fib(2) = 1)
    # L1->L2: 2000 XP (fib(3) = 2)
    # L2->L3: 3000 XP (fib(4) = 3)
    # L3->L4: 5000 XP (fib(5) = 5)
    # L4->L5: 8000 XP (fib(6) = 8)
    # L5->L6: 13000 XP (fib(7) = 13)
    # L10->L11: 144000 XP (fib(12) = 144)

    my $fib = $self->_fibonacci($self->{level} + 2);
    return $fib * 1000;
}

# Calculate nth fibonacci number
sub _fibonacci {
    my ($self, $n) = @_;
    return 0 if $n == 0;
    return 1 if $n == 1 || $n == 2;

    my ($a, $b) = (1, 1);
    for (my $i = 3; $i <= $n; $i++) {
        ($a, $b) = ($b, $a + $b);
    }
    return $b;
}

1;
