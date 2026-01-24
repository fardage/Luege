#!/bin/bash
# Start the Docker-based SMB test server for Luege integration tests.
#
# After starting, run tests with:
#   LUEGE_TEST_SMB_SERVER=localhost swift test --filter LuegeIntegrationTests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_ROOT/docker"

echo "Starting Luege SMB test server..."

# Ensure test data directories exist
mkdir -p "$DOCKER_DIR/test-data/TestShare"
mkdir -p "$DOCKER_DIR/test-data/Movies"
mkdir -p "$DOCKER_DIR/test-data/Music"

# Create sample files if they don't exist
[ -f "$DOCKER_DIR/test-data/TestShare/README.txt" ] || \
    echo "Luege TestShare - Integration Test Data" > "$DOCKER_DIR/test-data/TestShare/README.txt"
[ -f "$DOCKER_DIR/test-data/Movies/README.txt" ] || \
    echo "Luege Movies Share - Integration Test Data" > "$DOCKER_DIR/test-data/Movies/README.txt"
[ -f "$DOCKER_DIR/test-data/Music/README.txt" ] || \
    echo "Luege Music Share - Integration Test Data" > "$DOCKER_DIR/test-data/Music/README.txt"

# Start the container
cd "$DOCKER_DIR"
docker compose up -d

# Wait for Samba to be ready
echo "Waiting for Samba to start..."
sleep 3

echo ""
echo "=== SMB Test Server Started ==="
echo "Server: localhost:445"
echo "Shares: TestShare, Movies, Music"
echo ""
echo "To run integration tests:"
echo "  LUEGE_TEST_SMB_SERVER=localhost swift test --filter LuegeIntegrationTests"
echo ""
echo "To stop the server:"
echo "  ./scripts/stop-test-server.sh"
echo "==============================="
