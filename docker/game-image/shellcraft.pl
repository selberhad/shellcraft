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
my $player = Player->load_or_create('/home/soul.dat');

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

    # ANSI color codes
    my $CYAN = "\e[36m";
    my $GREEN = "\e[32m";
    my $YELLOW = "\e[33m";
    my $RED = "\e[31m";
    my $BOLD = "\e[1m";
    my $RESET = "\e[0m";

    # Calculate HP percentage for color
    my $max_hp = $player->max_hp();
    my $hp_percent = $max_hp > 0 ? ($player->{hp} / $max_hp) : 0;
    my $hp_color = $hp_percent < 0.3 ? $RED : ($hp_percent < 0.7 ? $YELLOW : $GREEN);

    print "${BOLD}${CYAN}Welcome back, $player->{name}!${RESET}\n";
    print "${BOLD}Level${RESET} ${YELLOW}$player->{level}${RESET} | ${BOLD}HP:${RESET} ${hp_color}$player->{hp}${RESET}/" . $player->max_hp() . " | ${BOLD}XP:${RESET} ${CYAN}$player->{xp}${RESET}/" . $player->xp_for_next_level() . "\n";
    print "\n";
    print "Type ${GREEN}'help'${RESET} for guidance, ${GREEN}'status'${RESET} to view your progress.\n";
    print "Type ${GREEN}'exit'${RESET} to save and quit.\n";
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

    # ANSI color codes
    my $CYAN = "\e[36m";
    my $GREEN = "\e[32m";
    my $YELLOW = "\e[33m";
    my $RED = "\e[31m";
    my $BOLD = "\e[1m";
    my $RESET = "\e[0m";

    # Calculate HP percentage for color
    my $max_hp = $player->max_hp();
    my $hp_percent = $max_hp > 0 ? ($player->{hp} / $max_hp) : 0;
    my $hp_color = $hp_percent < 0.3 ? $RED : ($hp_percent < 0.7 ? $YELLOW : $GREEN);

    print "\n";
    print "${BOLD}${CYAN}=== Character Status ===${RESET}\n";
    print "${BOLD}Name:${RESET}  $player->{name}\n";
    print "${BOLD}Level:${RESET} ${YELLOW}$player->{level}${RESET}\n";
    print "${BOLD}HP:${RESET}    ${hp_color}$player->{hp}${RESET} / $max_hp\n";
    print "${BOLD}XP:${RESET}    ${CYAN}$player->{xp}${RESET} / " . $player->xp_for_next_level() . "\n";
    print "\n";

    my @unlocked = Commands::get_unlocked_commands($player->{level});
    print "${BOLD}Unlocked Commands${RESET} (${GREEN}" . scalar(@unlocked) . "${RESET}):\n";

    my $cols = 4;
    my $count = 0;
    for my $cmd (@unlocked) {
        printf "  ${GREEN}%-15s${RESET}", $cmd;
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
        print "${BOLD}Next unlock${RESET} at ${YELLOW}Level $next_level${RESET}: ${CYAN}$next_unlock${RESET}\n";
        print "XP needed: ${YELLOW}$xp_needed${RESET}\n";
    }
    print "\n";
}

sub show_help {
    my ($player) = @_;

    # ANSI color codes
    my $CYAN = "\e[36m";
    my $GREEN = "\e[32m";
    my $YELLOW = "\e[33m";
    my $RED = "\e[31m";
    my $BOLD = "\e[1m";
    my $RESET = "\e[0m";

    print "\n";
    print "${BOLD}${CYAN}=== ShellCraft Help ===${RESET}\n";
    print "\n";
    print "${BOLD}${YELLOW}Built-in commands:${RESET}\n";
    print "  ${GREEN}status${RESET} - View your character stats and unlocked commands\n";
    print "  ${GREEN}help${RESET}   - Show this help message\n";
    print "  ${GREEN}exit${RESET}   - Save and quit the game\n";
    print "\n";
    print "${BOLD}${YELLOW}Core mechanics:${RESET}\n";
    print "  ${CYAN}\u2022${RESET} Execute commands to gain ${CYAN}XP${RESET} (bytes manipulated)\n";
    print "  ${CYAN}\u2022${RESET} Level up to unlock new commands and arguments\n";
    print "  ${CYAN}\u2022${RESET} Your ${GREEN}HP${RESET} is the size of ${BOLD}/home/soul.dat${RESET} (file size = health)\n";
    print "  ${CYAN}\u2022${RESET} Run ${BOLD}/home/quest${RESET} to view and accept quests\n";
    print "\n";
    print "${BOLD}${YELLOW}Combat (turn-based):${RESET}\n";
    print "  ${CYAN}\u2022${RESET} Enemies are files (.rat, .elf, daemon files)\n";
    print "  ${CYAN}\u2022${RESET} Attack by running: ${GREEN}rm <enemy_file>${RESET}\n";
    print "  ${CYAN}\u2022${RESET} Each turn: you attack, enemy attacks back\n";
    print "  ${CYAN}\u2022${RESET} Deal damage based on your level (truncates enemy file)\n";
    print "  ${CYAN}\u2022${RESET} Enemy deals damage = their max HP / 10 (reduces your soul.dat)\n";
    print "  ${CYAN}\u2022${RESET} ${GREEN}Victory${RESET}: enemy file deleted, you gain XP\n";
    print "  ${CYAN}\u2022${RESET} ${RED}Death${RESET}: soul.dat deleted (${BOLD}permadeath!${RESET})\n";
    print "\n";
    print "Use standard UNIX commands to interact with the world.\n";
    print "Your progress is saved in ${BOLD}/home/soul.dat${RESET}\n";
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
        # Write current PWD for DM quest tracking
        write_pwd();
        return 1;
    } else {
        # Failed
        print "cd: $dir: No such file or directory\n";
        return 0;
    }
}

sub write_pwd {
    use Cwd;
    my $pwd = getcwd();
    my $pwd_file = $ENV{HOME} . '/.pwd';

    if (open my $fh, '>', $pwd_file) {
        print $fh $pwd;
        close $fh;
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
