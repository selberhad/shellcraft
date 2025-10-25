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
        save_path   => $opts{save_path} || '/tmp/test_spellbook.dat',
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

# Check if command is unlocked
sub can_use {
    my ($self, $command) = @_;

    return Commands::is_unlocked($command, $self->{player}{level});
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
