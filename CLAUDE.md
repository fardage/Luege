# Luege - Development Guide

## Project Overview

Luege is a tvOS/iOS media player for playing content directly from SMB network shares. Built with SwiftUI and AMSMB2, targeting Apple TV, iPhone, and iPad.

**Key Technologies:** SwiftUI, AMSMB2, Network.framework (Bonjour), XcodeGen, VLCKit (optional, via CocoaPods)

## Development Workflow

### Building & Running

Always use the workspace: `open Luege.xcworkspace`

```bash
cd App && xcodegen generate          # After adding/removing source files
cd App && xcodegen generate && pod install  # After modifying project.yml
```

### Running Tests

```bash
make test-unit         # Unit tests only
make test-integration  # Integration tests with Docker
make test              # All tests
```

Pre-commit hook runs unit tests automatically. Install with `make install-hooks`.

### Docker Test Environment

```bash
./Tools/scripts/start-test-server.sh   # Start SMB server (localhost:445)
./Tools/scripts/stop-test-server.sh    # Stop SMB server
```

Test shares: `TestShare`, `Movies`, `Music` (guest:guest credentials)

### Screenshot Tests

```bash
# Record new snapshots: set isRecording = true in App/LuegeScreenshotTests/Shared/SnapshotTestCase.swift
xcodebuild test -workspace Luege.xcworkspace -scheme "LuegeScreenshotTests iOS" -destination "platform=iOS Simulator,name=iPhone 17"
xcodebuild test -workspace Luege.xcworkspace -scheme "LuegeScreenshotTests tvOS" -destination "platform=tvOS Simulator,name=Apple TV"
```

Snapshots are committed to the repo with platform suffixes (`.iOS.png`, `.tvOS.png`).

### Visual Verification with iOS Simulator MCP

After any UI changes, **always verify visually** using the iOS Simulator MCP tools before committing:

1. Build the iOS target, install via `mcp__ios-simulator__install_app`, launch with bundle ID `com.luege.app`
2. Navigate through all affected screens using `ui_tap`, `ui_swipe`
3. Screenshot each screen with `ui_view` to verify correctness
4. Check: tap targets work, layouts render correctly, images are aligned, navigation flows end-to-end

App location: `~/Library/Developer/Xcode/DerivedData/Luege-*/Build/Products/Debug-iphonesimulator/Luege.app`

## Code Architecture

### Directory Structure

```
App/Shared/
├── Core/           # Business logic (Browsing/, Discovery/, Models/, Persistence/, Metadata/, Playback/)
├── PlayerEngine/   # VLCPlayerEngine, PlayerFactory
├── Views/          # SwiftUI views
├── ViewModels/     # View models
└── Extensions/
App/LuegeCoreTests/          # Unit tests with mocks
App/LuegeIntegrationTests/   # Real network tests
App/LuegeScreenshotTests/    # Visual regression tests
```

### Design Principles

1. **Protocol-based design** — all components defined via protocols for testability
2. **Dependency injection** — services accept injected dependencies
3. **Async/await** — modern Swift concurrency throughout
4. **@MainActor isolation** — UI-bound services are main-actor isolated

## Security

**Never commit secrets** (API keys, passwords, credentials, private keys). Store credentials in Keychain. Review `git diff` before committing.

## Commit Convention

```
<type>: <short description>

<detailed description>

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

Types: `Implement`, `Add`, `Fix`, `Update`, `Refactor`

## Documentation

- `docs/02-implementation-concept.md` — Architecture decisions
- `docs/03-design-system.md` — UI/UX guidelines
- `docs/04-epic-and-stories.md` — User stories and acceptance criteria

## Current Status

### Completed Stories
E1-001 through E1-003 (Discovery & connections), E2-001/E2-002 (Browsing), E3-001 through E3-004 (Playback), E4-001 through E4-003 (Library), E5-001 (Movie metadata)

### Next Stories
- E5-002: Auto-fetch TV show metadata
- E7-002: Playback preferences (default audio track, subtitle styling)
