#!/bin/bash
# Stop the Docker-based SMB test server.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_ROOT/docker"

echo "Stopping Luege SMB test server..."

cd "$DOCKER_DIR"
docker compose down

echo "SMB test server stopped."
