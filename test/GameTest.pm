package GameTest;
use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';

# ShellCraft Gameplay Testing DSL
#
# Purpose: Simulate game sessions for regression testing, quest validation,
# and balance verification. Tests read like "speedruns" of gameplay.
#
# Example:
#   my $game = GameTest->new();
#   $game->start_fresh();
#   $game->expect_level(0);
#   $game->fight('/sewer/rat_1.rat');
#   $game->expect_level(1);
#   $game->expect_hp_at_least(80);
#   $game->save_or_die();

use Player;
use Commands;
use Combat;

# Constructor
sub new {
    my ($class, %opts) = @_;

    my $self = {
        player      => undef,
        save_path   => $opts{save_path} || '/tmp/test_soul.dat',
        verbose     => $opts{verbose} // 0,
        test_name   => $opts{test_name} || 'unnamed_test',
        assertions  => 0,
        failures    => 0,
    };

    return bless $self, $class;
}

# DSL Methods
# ===========

# Start a fresh game (new player, level 0)
sub start_fresh {
    my ($self) = @_;

    # Clean up any existing save
    unlink $self->{save_path} if -f $self->{save_path};

    # Create new player
    $self->{player} = Player->new();
    $self->log("Started fresh game");

    return $self;
}

# Load existing save
sub load_save {
    my ($self) = @_;

    $self->{player} = Player->load($self->{save_path});
    $self->log("Loaded save from $self->{save_path}");

    return $self;
}

# Save game
sub save_game {
    my ($self) = @_;

    $self->{player}->save($self->{save_path});
    $self->log("Saved game to $self->{save_path}");

    return $self;
}

# Add XP without fighting
sub add_xp {
    my ($self, $amount) = @_;

    my $old_level = $self->{player}{level};
    $self->{player}->add_xp($amount);
    my $new_level = $self->{player}{level};

    $self->log("Added $amount XP (L$old_level → L$new_level)");

    return $self;
}

# Set player stats directly (for testing specific scenarios)
sub set_stats {
    my ($self, %stats) = @_;

    $self->{player}{level} = $stats{level} if defined $stats{level};
    $self->{player}{xp}    = $stats{xp}    if defined $stats{xp};
    $self->{player}{hp}    = $stats{hp}    if defined $stats{hp};

    $self->log("Set stats: " . join(", ", map { "$_=$stats{$_}" } keys %stats));

    return $self;
}

# Simulate fighting an enemy
sub fight {
    my ($self, $enemy_path) = @_;

    # Create a temporary enemy file for testing
    my $enemy_hp = $self->_get_or_create_enemy($enemy_path);

    my $old_hp = $self->{player}{hp};
    my $old_xp = $self->{player}{xp};
    my $old_level = $self->{player}{level};

    # Silence combat output unless verbose
    local *STDOUT = $self->_get_output_handle();

    # Run combat
    Combat::handle_combat($self->{player}, $enemy_path);

    my $xp_gained = $self->{player}{xp} - $old_xp;
    my $hp_lost = $old_hp - $self->{player}{hp};
    my $leveled = $self->{player}{level} > $old_level;

    $self->log(sprintf(
        "Fought %s: %+d XP, -%d HP%s",
        $enemy_path,
        $xp_gained,
        $hp_lost,
        $leveled ? " [LEVELED UP!]" : ""
    ));

    return $self;
}

# Add a quest to player
sub add_quest {
    my ($self, $quest_id) = @_;

    my $success = $self->{player}->add_quest($quest_id);

    if ($success) {
        $self->log("Added quest $quest_id");
    } else {
        $self->log("Failed to add quest $quest_id (no slots or already active)");
    }

    return $self;
}

# Remove a quest from player
sub remove_quest {
    my ($self, $quest_id) = @_;

    my $removed = $self->{player}->remove_quest($quest_id);

    if ($removed) {
        $self->log("Removed quest $quest_id");
    } else {
        $self->log("Quest $quest_id was not active");
    }

    return $self;
}

# Check if command is unlocked
sub can_use {
    my ($self, $command) = @_;

    return Commands::is_unlocked($command, $self->{player}{level});
}

# Filesystem helpers
sub create_file {
    my ($self, $path, $content) = @_;

    open my $fh, '>', $path or die "Can't create file $path: $!";
    print $fh $content;
    close $fh;

    $self->log("Created file $path");

    return $self;
}

# Command execution helpers
sub run_command {
    my ($self, $command) = @_;

    my $output = `$command 2>&1`;
    my $exit_code = $? >> 8;

    $self->{last_command} = $command;
    $self->{last_output} = $output;
    $self->{last_exit_code} = $exit_code;

    $self->log("Ran command: $command (exit=$exit_code)");

    return $self;
}

sub get_command_output {
    my ($self, $command) = @_;

    $self->run_command($command);

    return $self->{last_output};
}

# Dungeon Master helpers
sub trigger_dm_tick {
    my ($self) = @_;

    # Try to run dungeon-master --tick
    # Note: DM runs as root, so this might fail in test environment
    # We handle this gracefully
    my $dm_path = '/usr/sbin/dungeon-master';

    if (-x $dm_path) {
        my $output = `$dm_path --tick 2>&1`;
        my $exit_code = $? >> 8;

        if ($exit_code == 0) {
            $self->log("DM tick executed successfully");
        } else {
            $self->log("DM tick failed (exit=$exit_code)");
            $self->log("DM output: $output") if $output;
        }
    } else {
        $self->log("DM not found or not executable - skipping tick");
    }

    # Reload player state from disk (DM may have modified soul.dat)
    if (-f $self->{save_path}) {
        $self->{player} = Player->load($self->{save_path});
        $self->log("Reloaded player state after DM tick");
    }

    return $self;
}

# Assertions
# ==========

sub expect_level {
    my ($self, $expected) = @_;

    $self->{assertions}++;
    my $actual = $self->{player}{level};

    if ($actual == $expected) {
        $self->log("✓ Level is $expected");
    } else {
        $self->fail("Expected level $expected, got $actual");
    }

    return $self;
}

sub expect_hp_at_least {
    my ($self, $min_hp) = @_;

    $self->{assertions}++;
    my $actual = $self->{player}{hp};

    if ($actual >= $min_hp) {
        $self->log("✓ HP $actual >= $min_hp");
    } else {
        $self->fail("Expected HP >= $min_hp, got $actual");
    }

    return $self;
}

sub expect_hp_at_most {
    my ($self, $max_hp) = @_;

    $self->{assertions}++;
    my $actual = $self->{player}{hp};

    if ($actual <= $max_hp) {
        $self->log("✓ HP $actual <= $max_hp");
    } else {
        $self->fail("Expected HP <= $max_hp, got $actual");
    }

    return $self;
}

sub expect_can_use {
    my ($self, $command) = @_;

    $self->{assertions}++;

    if ($self->can_use($command)) {
        $self->log("✓ Can use '$command'");
    } else {
        $self->fail("Expected to unlock '$command' at level $self->{player}{level}");
    }

    return $self;
}

sub expect_cannot_use {
    my ($self, $command) = @_;

    $self->{assertions}++;

    if (!$self->can_use($command)) {
        $self->log("✓ Cannot use '$command' (locked)");
    } else {
        $self->fail("Expected '$command' to be locked at level $self->{player}{level}");
    }

    return $self;
}

sub expect_alive {
    my ($self) = @_;

    $self->{assertions}++;

    if (!$self->{player}->is_dead()) {
        $self->log("✓ Player is alive");
    } else {
        $self->fail("Expected player to be alive");
    }

    return $self;
}

sub expect_dead {
    my ($self) = @_;

    $self->{assertions}++;

    if ($self->{player}->is_dead()) {
        $self->log("✓ Player is dead");
    } else {
        $self->fail("Expected player to be dead");
    }

    return $self;
}

sub expect_quest_active {
    my ($self, $quest_id) = @_;

    $self->{assertions}++;

    if ($self->{player}->has_quest($quest_id)) {
        $self->log("✓ Quest $quest_id is active");
    } else {
        $self->fail("Expected quest $quest_id to be active");
    }

    return $self;
}

sub expect_quest_not_active {
    my ($self, $quest_id) = @_;

    $self->{assertions}++;

    if (!$self->{player}->has_quest($quest_id)) {
        $self->log("✓ Quest $quest_id is not active");
    } else {
        $self->fail("Expected quest $quest_id to not be active");
    }

    return $self;
}

sub expect_quest_slots {
    my ($self, $expected) = @_;

    $self->{assertions}++;
    my $actual = $self->{player}->unlocked_quest_slots();

    if ($actual == $expected) {
        $self->log("✓ Quest slots: $expected");
    } else {
        $self->fail("Expected $expected quest slots, got $actual");
    }

    return $self;
}

sub expect_xp {
    my ($self, $expected) = @_;

    $self->{assertions}++;
    my $actual = $self->{player}{xp};

    if ($actual == $expected) {
        $self->log("✓ XP is $expected");
    } else {
        $self->fail("Expected XP $expected, got $actual");
    }

    return $self;
}

sub expect_xp_at_least {
    my ($self, $min_xp) = @_;

    $self->{assertions}++;
    my $actual = $self->{player}{xp};

    if ($actual >= $min_xp) {
        $self->log("✓ XP $actual >= $min_xp");
    } else {
        $self->fail("Expected XP >= $min_xp, got $actual");
    }

    return $self;
}

# Filesystem assertions
sub expect_file_exists {
    my ($self, $path) = @_;

    $self->{assertions}++;

    if (-f $path) {
        $self->log("✓ File exists: $path");
    } else {
        $self->fail("Expected file to exist: $path");
    }

    return $self;
}

sub expect_file_not_exists {
    my ($self, $path) = @_;

    $self->{assertions}++;

    if (!-f $path) {
        $self->log("✓ File does not exist: $path");
    } else {
        $self->fail("Expected file to NOT exist: $path");
    }

    return $self;
}

sub expect_dir_exists {
    my ($self, $path) = @_;

    $self->{assertions}++;

    if (-d $path) {
        $self->log("✓ Directory exists: $path");
    } else {
        $self->fail("Expected directory to exist: $path");
    }

    return $self;
}

sub expect_dir_not_exists {
    my ($self, $path) = @_;

    $self->{assertions}++;

    if (!-d $path) {
        $self->log("✓ Directory does not exist: $path");
    } else {
        $self->fail("Expected directory to NOT exist: $path");
    }

    return $self;
}

sub expect_file_contains {
    my ($self, $path, $pattern) = @_;

    $self->{assertions}++;

    # Read file contents
    if (!-f $path) {
        $self->fail("Cannot check file contents: $path does not exist");
        return $self;
    }

    open my $fh, '<', $path or do {
        $self->fail("Cannot read file: $path");
        return $self;
    };

    my $content = do { local $/; <$fh> };
    close $fh;

    # Check if pattern matches
    my $matches = ref($pattern) eq 'Regexp'
        ? $content =~ /$pattern/
        : $content =~ /\Q$pattern\E/;

    if ($matches) {
        $self->log("✓ File contains pattern: $path");
    } else {
        $self->fail("Expected file to contain pattern '$pattern': $path");
    }

    return $self;
}

# Command execution assertions
sub expect_command_success {
    my ($self, $command) = @_;

    $self->{assertions}++;

    $self->run_command($command);

    if ($self->{last_exit_code} == 0) {
        $self->log("✓ Command succeeded: $command");
    } else {
        $self->fail("Expected command to succeed (exit 0), got exit code $self->{last_exit_code}: $command");
    }

    return $self;
}

sub expect_command_fails {
    my ($self, $command) = @_;

    $self->{assertions}++;

    $self->run_command($command);

    if ($self->{last_exit_code} != 0) {
        $self->log("✓ Command failed as expected: $command");
    } else {
        $self->fail("Expected command to fail (exit non-zero), but got exit 0: $command");
    }

    return $self;
}

# Save and die if player is dead (for permadeath testing)
sub save_or_die {
    my ($self) = @_;

    if ($self->{player}->is_dead()) {
        $self->log("Player died - deleting save");
        unlink $self->{save_path};
    } else {
        $self->save_game();
    }

    return $self;
}

# Test result reporting
# =====================

sub report {
    my ($self) = @_;

    print "\n";
    print "=" x 60 . "\n";
    print "Test: $self->{test_name}\n";
    print "=" x 60 . "\n";
    print "Assertions: $self->{assertions}\n";
    print "Failures:   $self->{failures}\n";

    if ($self->{failures} == 0) {
        print "Result:     ✓ PASS\n";
    } else {
        print "Result:     ✗ FAIL\n";
    }
    print "=" x 60 . "\n";
    print "\n";

    return $self->{failures} == 0;
}

# Internal helpers
# ================

# XP Calculation Helpers
# Calculate XP threshold for a specific level (matches Player.pm formula)
# This is the XP needed AT that level to reach the NEXT level
sub xp_for_level {
    my ($self, $level) = @_;
    my $fib = $self->_fibonacci($level + 2);
    return $fib * 1000;
}

# Calculate total XP needed to reach target_level from current_level
sub xp_to_reach_level {
    my ($self, $from_level, $to_level) = @_;
    my $total = 0;
    for (my $lvl = $from_level; $lvl < $to_level; $lvl++) {
        $total += $self->xp_for_level($lvl);
    }
    return $total;
}

# Add just enough XP to level up once from current level
sub level_up_once {
    my ($self) = @_;
    my $current_level = $self->{player}{level};
    my $current_xp = $self->{player}{xp};
    my $threshold = $self->{player}->xp_for_next_level();
    my $xp_needed = $threshold - $current_xp;
    return $self->add_xp($xp_needed);
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

sub log {
    my ($self, $msg) = @_;

    return unless $self->{verbose};

    print "[TEST] $msg\n";
}

sub fail {
    my ($self, $msg) = @_;

    $self->{failures}++;
    print "[FAIL] $msg\n";
}

sub _get_output_handle {
    my ($self) = @_;

    if ($self->{verbose}) {
        return *STDOUT;
    } else {
        # Silence output
        open my $null, '>', '/dev/null';
        return $null;
    }
}

sub _get_or_create_enemy {
    my ($self, $path) = @_;

    # If enemy exists, return its HP
    return -s $path if -f $path;

    # Otherwise create a test enemy based on path
    my $hp = 100;  # Default small rat

    $hp = 200 if $path =~ /rat_[2-5]/;
    $hp = 400 if $path =~ /rat_large/;
    $hp = 800 if $path =~ /skeleton/;
    $hp = 1200 if $path =~ /daemon/;

    # Create enemy file
    open my $fh, '>', $path or die "Can't create test enemy $path: $!";
    print $fh "\0" x $hp;
    close $fh;

    return $hp;
}

1;
