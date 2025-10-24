package Commands;
use strict;
use warnings;

# Command unlock table from GAMESHELL.md
my %UNLOCKS = (
    0  => [qw(ls cat echo rm cd pwd whoami mkdir touch)],
    1  => ['ls -l', 'ls -a', 'ls -la'],
    2  => [qw(mv cp)],
    3  => [qw(rmdir)],
    4  => [qw(file wc)],
    5  => [qw(head tail)],
    6  => [qw(grep)],
    7  => ['grep -i', 'grep -n', 'grep -v'],
    8  => [qw(sort)],
    9  => [qw(uniq)],
    10 => ['wc -l', 'wc -w', 'wc -c'],
    11 => ['head -n', 'tail -n', 'tail -f'],
    12 => [qw(find)],
    13 => [qw(awk)],
    14 => [qw(sed)],
    15 => [qw(chmod)],
    16 => [qw(chown)],
    17 => [qw(ps)],
    18 => [qw(kill)],
    19 => [qw(tar)],
    20 => ['perl -e'],
);

# Base commands that are always available (level 0)
my @BASE_COMMANDS = qw(
    ls cat echo rm cd pwd whoami mkdir touch
    status help exit quit
);

# Check if a command is unlocked at the given level
sub is_unlocked {
    my ($cmd, $level) = @_;

    # Extract base command (before arguments/flags)
    my $base_cmd = (split /\s+/, $cmd)[0];

    # Built-in game commands are always available
    return 1 if grep { $_ eq $base_cmd } qw(status help exit quit);

    # Check level 0 commands
    return 1 if $level >= 0 && grep { $_ eq $base_cmd } @BASE_COMMANDS;

    # Check all unlocks up to current level
    for my $unlock_level (1 .. $level) {
        next unless exists $UNLOCKS{$unlock_level};

        for my $unlocked_cmd (@{$UNLOCKS{$unlock_level}}) {
            # Handle both base commands and command+arg patterns
            my $unlocked_base = (split /\s+/, $unlocked_cmd)[0];

            return 1 if $base_cmd eq $unlocked_base;
            return 1 if $cmd eq $unlocked_cmd;
        }
    }

    return 0;
}

# Get all commands unlocked at or below the given level
sub get_unlocked_commands {
    my ($level) = @_;

    my @commands = @BASE_COMMANDS;

    for my $unlock_level (1 .. $level) {
        next unless exists $UNLOCKS{$unlock_level};
        push @commands, @{$UNLOCKS{$unlock_level}};
    }

    return @commands;
}

# Get the command/feature unlocked at a specific level
sub unlock_at_level {
    my ($level) = @_;

    return undef unless exists $UNLOCKS{$level};

    my @unlocks = @{$UNLOCKS{$level}};
    return join(', ', @unlocks);
}

# Get level required for a command
sub level_required {
    my ($cmd) = @_;

    my $base_cmd = (split /\s+/, $cmd)[0];

    # Check base commands
    return 0 if grep { $_ eq $base_cmd } @BASE_COMMANDS;

    # Check unlock table
    for my $unlock_level (sort { $a <=> $b } keys %UNLOCKS) {
        for my $unlocked_cmd (@{$UNLOCKS{$unlock_level}}) {
            my $unlocked_base = (split /\s+/, $unlocked_cmd)[0];

            return $unlock_level if $base_cmd eq $unlocked_base;
            return $unlock_level if $cmd eq $unlocked_cmd;
        }
    }

    return 999;  # Unknown command
}

1;
