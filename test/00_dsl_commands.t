#!/usr/bin/env perl
# Test: DSL Command Execution
#
# Verifies:
# - run_command() executes shell commands
# - expect_command_success() validates exit code 0
# - expect_command_fails() validates non-zero exit
# - get_command_output() returns stdout

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

# Create test
my $game = GameTest->new(
    test_name => 'DSL Command Execution',
    verbose   => 1,
    save_path => '/tmp/test_dsl_commands.dat',
);

# Start fresh to initialize player (DSL requires player object)
$game->start_fresh();

# Test 1: run_command() with successful command
$game->run_command('echo "Hello from command"');

# Test 2: expect_command_success() with command that exits 0
$game->expect_command_success('ls /tmp');

# Test 3: expect_command_success() with command that creates output
$game->expect_command_success('echo "test" > /tmp/cmd_test.txt');

# Test 4: get_command_output() captures stdout
$game->create_file('/tmp/cmd_output_test.txt', 'test');  # Create test file first
my $output = $game->get_command_output('echo "captured"');
# Verify output was actually captured (contains the word "captured")
die "Output not captured correctly" unless $output =~ /captured/;

# Test 5: expect_command_fails() with command that exits non-zero
$game->expect_command_fails('ls /nonexistent_directory_xyz');

# Test 6: Run command and check its side effects
$game->run_command('touch /tmp/created_by_command.txt')
     ->expect_file_exists('/tmp/created_by_command.txt');

# Test 7: expect_command_success() with complex command (pipes)
$game->expect_command_success('echo "line1\nline2\nline3" | grep line2');

# Cleanup
unlink '/tmp/cmd_test.txt';
unlink '/tmp/cmd_output_test.txt';
unlink '/tmp/created_by_command.txt';

# Report results
exit($game->report() ? 0 : 1);
