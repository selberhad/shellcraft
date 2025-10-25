#!/bin/bash
# ShellCraft Test Runner
#
# Runs all gameplay tests by mounting them into containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Image name
IMAGE="${SHELLCRAFT_IMAGE:-shellcraft/game:latest}"

echo "=========================================="
echo "  ShellCraft Gameplay Tests"
echo "=========================================="
echo "Image: $IMAGE"
echo ""

# Track results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Run each test in a container
for test_file in *.t; do
    if [ -f "$test_file" ]; then
        echo "Running: $test_file"
        echo "------------------------------------------"

        # Run test in container with GameTest.pm and test file mounted
        if docker run --rm \
            -v "$SCRIPT_DIR/GameTest.pm:/tmp/GameTest.pm:ro" \
            -v "$SCRIPT_DIR/$test_file:/tmp/test.t:ro" \
            -e SHELLCRAFT_NO_DELAY=1 \
            -e PERL5LIB=/usr/local/lib/shellcraft:/tmp \
            "$IMAGE" \
            perl /tmp/test.t; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi

        TESTS_RUN=$((TESTS_RUN + 1))
        echo ""
    fi
done

# Summary
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
echo "Total:   $TESTS_RUN"
echo "Passed:  $TESTS_PASSED"
echo "Failed:  $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "Result:  ✓ ALL TESTS PASSED"
    exit 0
else
    echo "Result:  ✗ SOME TESTS FAILED"
    exit 1
fi
