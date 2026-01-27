#!/bin/bash
# Convenience script to start the test server and run integration tests.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Start the server
"$SCRIPT_DIR/start-test-server.sh"

# Give Samba extra time to fully initialize
sleep 2

# Run the tests
echo ""
echo "Running integration tests..."
echo ""

cd "$PROJECT_ROOT"
LUEGE_TEST_SMB_SERVER=localhost swift test --filter LuegeIntegrationTests

echo ""
echo "Tests complete. Server still running."
echo "Run ./Tools/scripts/stop-test-server.sh when done."
