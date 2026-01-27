.PHONY: test test-unit test-integration test-all install-hooks

# Run unit tests (no network required)
test-unit:
	swift test --filter LuegeCoreTests

# Run integration tests with Docker (starts/stops server automatically)
test-integration:
	./Tools/scripts/run-integration-tests.sh

# Run all tests
test-all: test-unit test-integration

# Alias for test-all
test: test-all

# Install git pre-commit hook
install-hooks:
	cp Tools/scripts/pre-commit .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed!"

# Start the Docker test server
start-server:
	./Tools/scripts/start-test-server.sh

# Stop the Docker test server
stop-server:
	./Tools/scripts/stop-test-server.sh
