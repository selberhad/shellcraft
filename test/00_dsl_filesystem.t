#!/usr/bin/env perl
# Test: DSL Filesystem Assertions
#
# Verifies:
# - expect_file_exists() works for files
# - expect_dir_exists() works for directories
# - expect_file_contains() can grep file contents
# - Negative assertions fail correctly

use strict;
use warnings;
use lib '/usr/local/lib/shellcraft';
use lib '/tmp';  # GameTest.pm mounted here
use GameTest;

# Create test
my $game = GameTest->new(
    test_name => 'DSL Filesystem Assertions',
    verbose   => 1,
    save_path => '/tmp/test_dsl_filesystem.dat',
);

# Start fresh to initialize player (DSL requires player object)
$game->start_fresh();

# Test 1: expect_file_exists() positive case
# Create a test file first
$game->create_file('/tmp/test_file.txt', "Hello world\n")
     ->expect_file_exists('/tmp/test_file.txt');

# Test 2: expect_dir_exists() positive case
# /tmp directory should always exist
$game->expect_dir_exists('/tmp');

# Test 3: expect_file_contains() positive case
$game->expect_file_contains('/tmp/test_file.txt', 'Hello');

# Test 4: expect_file_contains() with regex pattern
$game->expect_file_contains('/tmp/test_file.txt', qr/w[o]rld/);

# Test 5: Create a file with multi-line content
$game->create_file('/tmp/multiline.txt', "Line 1\nLine 2\nLine 3\n")
     ->expect_file_contains('/tmp/multiline.txt', 'Line 2');

# Test 6: expect_file_not_exists() negative case (file should NOT exist)
$game->expect_file_not_exists('/tmp/nonexistent_file.txt');

# Test 7: expect_dir_not_exists() negative case
$game->expect_dir_not_exists('/tmp/nonexistent_dir');

# Cleanup test files
unlink '/tmp/test_file.txt';
unlink '/tmp/multiline.txt';

# Report results
exit($game->report() ? 0 : 1);
