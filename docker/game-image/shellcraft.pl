#!/usr/bin/env perl
use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';

# Disable output buffering for immediate display
$| = 1;
STDOUT->autoflush(1);
STDERR->autoflush(1);

# Load game modules
use Player;
use Commands;
use Combat;

# Initialize player or load save
my $player = Player->load_or_create('/home/spellbook.dat');

# Print player stats (welcome banner is shown by server)
print_player_stats($player);

# Main game loop
while (1) {
    # Print prompt
    print_prompt($player);

    # Read command
    my $input = <STDIN>;
    last unless defined $input;  # EOF (Ctrl+D)
    chomp $input;

    # Skip empty lines
    next if $input =~ /^\s*$/;

    # Parse command and arguments
    my ($cmd, @args) = parse_command($input);

    # Handle built-in game commands
    if ($cmd eq 'exit' || $cmd eq 'quit') {
        print "Saving your progress...\n";
        $player->save();
        print "Farewell, adventurer. May your paths be clear.\n";
        last;
    }

    if ($cmd eq 'status') {
        show_status($player);
        next;
    }

    if ($cmd eq 'help') {
        show_help($player);
        next;
    }

    # Check if command is unlocked (pass full input to validate arguments)
    unless (Commands::is_unlocked($input, $player->{level})) {
        print_locked_message($input);
        next;
    }

    # Handle shell builtins that can't be executed via system()
    if ($cmd eq 'cd') {
        handle_cd(@args);
        next;
    }

    if ($cmd eq 'pwd') {
        use Cwd;
        print getcwd() . "\n";
        $player->add_xp(1);
        next;
    }

    # Handle combat commands
    if ($cmd eq 'rm' && @args && is_enemy_file($args[0])) {
        Combat::handle_combat($player, $args[0]);
        $player->save();
        next;
    }

    # Execute real command
    execute_command($input, $player);

    # Update activity timestamp
    $player->{last_activity} = time();
}

# ============================================================================
# Helper Functions
# ============================================================================

sub print_player_stats {
    my ($player) = @_;

    print "Welcome back, $player->{name}!\n";
    print "Level $player->{level} | HP: $player->{hp}/" . $player->max_hp() . " | XP: $player->{xp}/" . $player->xp_for_next_level() . "\n";
    print "\n";
    print "Type 'help' for guidance, 'status' to view your progress.\n";
    print "Type 'exit' to save and quit.\n";
    print "\n";
}

sub print_prompt {
    my ($player) = @_;
    my $level_indicator = $player->{level} > 0 ? "[L$player->{level}] " : "";
    print "${level_indicator}\$> ";
}

sub parse_command {
    my ($input) = @_;

    # Split on whitespace, handling quotes
    my @parts = $input =~ /(?:[^\s"']+|"[^"]*"|'[^']*')+/g;

    # Remove quotes from arguments
    @parts = map { s/^["']|["']$//gr } @parts;

    return @parts;
}

sub print_locked_message {
    my ($cmd) = @_;

    my @messages = (
        "You lack the wisdom to wield '$cmd'. Train harder, apprentice.",
        "The power of '$cmd' is beyond your current understanding.",
        "'$cmd' remains locked. Gain more experience to unlock it.",
        "You attempt to invoke '$cmd', but the spell fizzles. You need more training.",
        "The ancient art of '$cmd' is not yet yours to command.",
    );

    print $messages[int(rand(@messages))] . "\n";
}

sub show_status {
    my ($player) = @_;

    print "\n";
    print "=== Character Status ===\n";
    print "Name:  $player->{name}\n";
    print "Level: $player->{level}\n";
    print "HP:    $player->{hp} / " . $player->max_hp() . "\n";
    print "XP:    $player->{xp} / " . $player->xp_for_next_level() . "\n";
    print "\n";

    my @unlocked = Commands::get_unlocked_commands($player->{level});
    print "Unlocked Commands (" . scalar(@unlocked) . "):\n";

    my $cols = 4;
    my $count = 0;
    for my $cmd (@unlocked) {
        printf "  %-15s", $cmd;
        $count++;
        print "\n" if $count % $cols == 0;
    }
    print "\n" if $count % $cols != 0;
    print "\n";

    # Show next unlock
    my $next_level = $player->{level} + 1;
    my $next_unlock = Commands::unlock_at_level($next_level);
    if ($next_unlock) {
        my $xp_needed = $player->xp_for_next_level() - $player->{xp};
        print "Next unlock at Level $next_level: $next_unlock\n";
        print "XP needed: $xp_needed\n";
    }
    print "\n";
}

sub show_help {
    my ($player) = @_;

    print "\n";
    print "=== ShellCraft Help ===\n";
    print "\n";
    print "Built-in commands:\n";
    print "  status - View your character stats and unlocked commands\n";
    print "  help   - Show this help message\n";
    print "  exit   - Save and quit the game\n";
    print "\n";
    print "Game mechanics:\n";
    print "  - Execute commands to gain XP (bytes manipulated)\n";
    print "  - Level up to unlock new commands and arguments\n";
    print "  - Fight enemies in /sewer by removing their files\n";
    print "  - Explore /crypt, /tower, and /etc/scrolls for quests\n";
    print "\n";
    print "Use standard UNIX commands to interact with the world.\n";
    print "Your progress is saved in /home/spellbook.dat\n";
    print "\n";
}

sub is_enemy_file {
    my ($path) = @_;
    return 0 unless defined $path;
    return 1 if $path =~ /\.rat$/;
    return 1 if $path =~ /\.elf$/;
    return 1 if $path =~ /daemon/;
    return 0;
}

sub handle_cd {
    my ($dir) = @_;

    # Default to home if no argument
    $dir = $ENV{HOME} || '/home' unless defined $dir && $dir ne '';

    # Attempt to change directory
    if (chdir $dir) {
        # Success - directory changed
        return 1;
    } else {
        # Failed
        print "cd: $dir: No such file or directory\n";
        return 0;
    }
}

sub execute_command {
    my ($cmd, $player) = @_;

    # Execute the command and capture exit status
    system($cmd);

    # Award XP based on command complexity (simple heuristic for now)
    my $xp_gain = 1;  # Base XP for any command

    # Give bonus XP for certain commands
    $xp_gain += 5 if $cmd =~ /\|/;      # Using pipes
    $xp_gain += 3 if $cmd =~ />/;       # Redirection
    $xp_gain += 2 if $cmd =~ /grep/;    # Text processing
    $xp_gain += 2 if $cmd =~ /awk|sed/; # Advanced text tools

    $player->add_xp($xp_gain);
}
