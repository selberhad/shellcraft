#!/bin/bash
# Build the ShellCraft game Docker image
# Must be run from repo root to include rust-bins in build context

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "  Building ShellCraft Game Image"
echo "=========================================="
echo "Build context: $(pwd)"
echo "Dockerfile: docker/game-image/Dockerfile"
echo ""

# Build from repo root with Dockerfile in docker/game-image
docker build -f docker/game-image/Dockerfile -t shellcraft/game:latest .

echo ""
echo "=========================================="
echo "  Build Complete!"
echo "=========================================="
echo ""
docker images shellcraft/game:latest
