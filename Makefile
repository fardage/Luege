.PHONY: test test-unit test-integration test-screenshot test-all install-hooks generate

# Run unit tests (no network required)
test-unit:
	xcodebuild test -workspace Luege.xcworkspace -scheme "LuegeCoreTests iOS" -destination "platform=iOS Simulator,name=iPhone 17" -parallel-testing-enabled NO -quiet

# Run integration tests with Docker (starts/stops server automatically)
test-integration:
	./Tools/scripts/run-integration-tests.sh

# Run screenshot tests
test-screenshot:
	xcodebuild test -workspace Luege.xcworkspace -scheme "LuegeScreenshotTests iOS" -destination "platform=iOS Simulator,name=iPhone 17" -quiet

# Run all tests
test-all: test-unit test-screenshot

# Alias for test-all
test: test-all

# Regenerate Xcode project
generate:
	cd App && xcodegen generate && pod install

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
