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
        quests        => $args{quests} || [(0) x 8],       # 8 quest slots, 0 = empty
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

    # Skip checksum (8 bytes)
    seek($fh, 8, 1);

    # Read level (4 bytes)
    read($fh, $data, 4);
    my $level = unpack('L<', $data);

    # Read XP (8 bytes, u64)
    read($fh, $data, 8);
    my $xp = unpack('Q<', $data);

    # Read quest slots (32 bytes = 8 x u32)
    read($fh, $data, 32);
    my @quests = unpack('L<8', $data);

    close $fh;

    # HP is the "telomere" - the file size minus the header
    # Header: 4 (magic) + 2 (version) + 8 (checksum) + 4 (level) + 8 (xp) + 32 (quests) = 58 bytes
    my $header_size = 58;
    my $hp = $file_size - $header_size;

    # Clamp HP to max for level (in case of corruption)
    my $max_hp = $class->max_hp($level);
    $hp = $max_hp if $hp > $max_hp;
    $hp = 0 if $hp < 0;

    my $player = $class->new(
        level  => $level,
        xp     => $xp,
        hp     => $hp,
        quests => \@quests,
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
    my @quests = @{$self->{quests}};
    print $fh pack('L<8', @quests);

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

# Get number of unlocked quest slots for current level
# Formula: 1 slot at L0, +1 every 6 levels, max 8 at L42
sub unlocked_quest_slots {
    my ($self) = @_;
    my $slots = 1 + int($self->{level} / 6);
    return $slots > 8 ? 8 : $slots;
}

# Get active quests (non-zero quest IDs in unlocked slots)
sub active_quests {
    my ($self) = @_;
    my $unlocked = $self->unlocked_quest_slots();
    my @active;

    for (my $i = 0; $i < $unlocked; $i++) {
        my $quest_id = $self->{quests}[$i];
        push @active, $quest_id if $quest_id != 0;
    }

    return @active;
}

# Check if a quest is active
sub has_quest {
    my ($self, $quest_id) = @_;
    my @active = $self->active_quests();
    return grep { $_ == $quest_id } @active;
}

# Add a quest to the first available slot
sub add_quest {
    my ($self, $quest_id) = @_;

    return 0 if $quest_id == 0;  # Can't add quest 0 (empty marker)
    return 0 if $self->has_quest($quest_id);  # Already active

    my $unlocked = $self->unlocked_quest_slots();
    for (my $i = 0; $i < $unlocked; $i++) {
        if ($self->{quests}[$i] == 0) {
            $self->{quests}[$i] = $quest_id;
            return 1;
        }
    }

    return 0;  # No slots available
}

# Remove a quest from all slots
sub remove_quest {
    my ($self, $quest_id) = @_;
    my $removed = 0;

    for (my $i = 0; $i < 8; $i++) {
        if ($self->{quests}[$i] == $quest_id) {
            $self->{quests}[$i] = 0;
            $removed = 1;
        }
    }

    return $removed;
}

1;
