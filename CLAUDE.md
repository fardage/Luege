# Luege - Development Guide

## Project Overview

Luege is a tvOS/iOS media player for playing content directly from SMB network shares. Built with SwiftUI and AMSMB2, targeting Apple TV, iPhone, and iPad.

**Key Technologies:**
- Swift Package Manager
- SwiftUI (native-first approach)
- AMSMB2 for SMB2/3 protocol
- Network.framework for Bonjour/mDNS discovery
- XcodeGen for Xcode project generation

## Development Workflow

### Story Implementation Cycle

1. **Read the story** from `docs/04-epic-and-stories.md`
2. **Plan the implementation** - create protocol-based design for testability
3. **Implement core logic** in `Sources/LuegeCore/`
4. **Write unit tests** with mocks in `Tests/LuegeCoreTests/`
5. **Write integration tests** in `Tests/LuegeIntegrationTests/`
6. **Verify with Docker test environment** (`make test-integration`)
7. **Update story status** in docs (mark acceptance criteria as complete)
8. **Commit** - pre-commit hook runs tests automatically

### Running Tests

**Quick commands (via Makefile):**
```bash
make test-unit         # Unit tests only
make test-integration  # Integration tests with Docker
make test              # All tests
```

**Manual commands:**
```bash
# Unit tests (no network required)
swift test --filter LuegeCoreTests

# Integration tests with Docker
./Tools/scripts/start-test-server.sh
LUEGE_TEST_SMB_SERVER=localhost swift test --filter LuegeIntegrationTests
./Tools/scripts/stop-test-server.sh

# All tests
swift test
```

### Pre-commit Hooks

The project includes a pre-commit hook that automatically runs tests before each commit:

**Install the hook:**
```bash
make install-hooks
```

**What it does:**
- Always runs unit tests before allowing a commit
- Also runs integration tests with the test server (`luege-test-smb` container)
- Blocks the commit if any tests fail

**Workflow:**
1. Install the hook once: `make install-hooks`
2. Start Docker test server when working on SMB features: `make start-server`
3. Commit as normal - tests run automatically
4. Stop server when done: `make stop-server`

**Bypassing (not recommended):**
```bash
git commit --no-verify -m "message"  # Skips pre-commit hook
```

### Xcode Workspace

**Opening the project:**
```bash
open Luege.xcworkspace
```

Always use the workspace (not `App/Luege.xcodeproj` directly) as it provides unified access to both the app project and the LuegeCore Swift package in a single window.

### XcodeGen

The Xcode project is generated using XcodeGen. After adding new source files:

```bash
cd App && xcodegen generate
```

The `project.yml` defines targets for iOS, tvOS, and screenshot tests. Source files in `Shared/` are automatically included in both platform targets. The workspace uses relative paths, so regenerating the Xcode project won't break the workspace.

### Docker Test Environment

The project includes a Docker-based Samba server for integration testing:

```bash
./Tools/scripts/start-test-server.sh   # Start SMB server (localhost:445)
./Tools/scripts/stop-test-server.sh    # Stop SMB server
./Tools/scripts/run-integration-tests.sh  # Start + run tests
```

Test shares: `TestShare`, `Movies`, `Music` (guest:guest credentials)

## Code Architecture

### Directory Structure

```
Sources/LuegeCore/
├── Browsing/            # Directory browsing components
│   ├── BrowsingProtocols.swift     # DirectoryBrowsing protocol
│   ├── BrowsingError.swift         # Error types
│   └── SMBDirectoryBrowser.swift   # AMSMB2 implementation
├── Discovery/           # Network discovery components
│   ├── DiscoveryProtocols.swift    # Protocol definitions
│   ├── BonjourBrowser.swift        # mDNS service discovery
│   ├── SMBShareEnumerator.swift    # SMB share listing
│   ├── SMBConnectionTester.swift   # Manual share connection testing
│   ├── SMBStatusChecker.swift      # Connection status checking
│   ├── ConnectionStatusProtocols.swift  # Status management protocols
│   ├── ConnectionStatusService.swift    # Status tracking service
│   └── NetworkDiscoveryService.swift    # Main orchestrator
├── Models/
│   ├── DiscoveredShare.swift       # Share data model
│   ├── SavedShare.swift            # Persistent share model
│   ├── ConnectionStatus.swift      # Status enum
│   ├── ShareCredentials.swift      # Authentication credentials
│   ├── ManualShareInput.swift      # Manual share input model
│   └── FileEntry.swift             # File/folder entry model
├── Playback/            # Video playback components
│   ├── PlaybackProtocols.swift     # SMBFileReading protocol
│   ├── PlaybackState.swift         # Playback state enum
│   ├── PlaybackError.swift         # Error types
│   ├── SMBFileReader.swift         # AMSMB2 file reading
│   └── SMBResourceLoaderDelegate.swift  # AVPlayer bridge
└── Persistence/         # Persistent storage components
    ├── PersistenceProtocols.swift  # Storage protocols
    ├── KeychainService.swift       # Secure credential storage
    ├── FileShareStorage.swift      # JSON metadata storage
    └── SavedShareStorageService.swift  # Combined persistence

App/Shared/
├── Views/               # SwiftUI views
│   ├── FolderBrowserView.swift     # Directory browsing view
│   ├── FileEntryRow.swift          # File/folder row component
│   ├── BreadcrumbBar.swift         # Navigation breadcrumb
│   ├── VideoPlayerView.swift       # Full-screen video player
│   ├── VideoPlayerLayer.swift      # AVPlayerLayer UIKit wrapper
│   ├── VideoControlsOverlay.swift  # Transport controls UI
│   ├── VideoErrorView.swift        # Error state UI
│   └── ...
└── ViewModels/          # View models
    ├── FolderBrowserViewModel.swift  # Browsing state management
    ├── VideoPlayerViewModel.swift    # Playback state management
    └── ...

Tests/
├── LuegeCoreTests/      # Unit tests with mocks
│   └── Mocks/           # Mock implementations
└── LuegeIntegrationTests/  # Real network tests
```

### Design Principles

1. **Protocol-based design** - All components defined via protocols for testability
2. **Dependency injection** - Services accept injected dependencies
3. **Async/await** - Modern Swift concurrency throughout
4. **@MainActor isolation** - UI-bound services are main-actor isolated

### Testing Strategy

- **Unit tests**: Use mocks to test logic without network
- **Integration tests**: Use Docker Samba server for real SMB testing
- **Bonjour tests**: Skip in Docker environment (mDNS doesn't cross network boundaries)
- **Screenshot tests**: Visual regression tests for UI components

### Screenshot Tests

The project includes snapshot tests for visual regression testing of UI components.

**Running screenshot tests:**
```bash
# iOS tests
xcodebuild test -workspace Luege.xcworkspace -scheme "LuegeScreenshotTests iOS" -destination "platform=iOS Simulator,name=iPhone 17"

# tvOS tests
xcodebuild test -workspace Luege.xcworkspace -scheme "LuegeScreenshotTests tvOS" -destination "platform=tvOS Simulator,name=Apple TV"
```

Note: Use `-workspace Luege.xcworkspace` (not `-project`) for running tests from the command line.

**Recording new snapshots:**
1. Set `isRecording = true` in `App/LuegeScreenshotTests/Shared/SnapshotTestCase.swift`
2. Run the tests for both platforms
3. Set `isRecording = false`
4. Run tests again to verify they pass

**After building or adjusting UI:**
1. Always run screenshot tests for both iOS and tvOS
2. Review the generated snapshots in `App/LuegeScreenshotTests/__Snapshots__/`
3. Verify the UI looks correct on both platforms
4. Check both light mode and dark mode variants
5. Commit updated snapshots so CI can catch visual regressions

Snapshots are committed to the repository and named with platform suffixes (`.iOS.png`, `.tvOS.png`).

## Documentation

- `docs/01-luege-naming-decision.md` - Project name rationale
- `docs/02-implementation-concept.md` - Architecture decisions
- `docs/03-design-system.md` - UI/UX guidelines (native SwiftUI)
- `docs/04-epic-and-stories.md` - User stories and acceptance criteria

## Security Best Practices

**Never commit secrets.** This includes:
- API keys and tokens
- Passwords and credentials
- Private keys and certificates
- Environment-specific configuration with sensitive data

**Before committing:**
- Review `git diff` for accidental credential exposure
- Use environment variables for sensitive configuration
- Store credentials in Keychain (iOS/macOS) or secure storage
- Keep `.env` files gitignored

**Code security:**
- Validate and sanitize all user input
- Use parameterized queries (no string concatenation for paths/URLs)
- Follow principle of least privilege for network operations
- Handle errors without exposing internal details to users

## Commit Convention

```
<type>: <short description>

<detailed description>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Types: `Implement`, `Add`, `Fix`, `Update`, `Refactor`

**Pre-commit checklist:**
- [ ] No secrets or credentials in code
- [ ] No hardcoded sensitive URLs or IPs
- [ ] Tests pass (enforced by pre-commit hook)
- [ ] Code reviewed for security issues

## Current Status

### Completed Stories
- ✅ E1-001: Auto-discover SMB network shares
- ✅ E1-002: Manually add a share
- ✅ E1-003: Save and manage connections
- ✅ E2-001: Browse folder structure
- ✅ E2-002: Filter to video files
- ✅ E3-001: Play video files

### Next Stories
- E3-002: Support common video formats
