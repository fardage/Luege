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

After any UI changes, **always verify visually** using the iOS Simulator MCP tools before committing.

**Always use "iPhone 17" as the simulator device** for builds and MCP verification:
```bash
xcodebuild build -workspace Luege.xcworkspace -scheme "Luege iOS" -destination "platform=iOS Simulator,name=iPhone 17" -quiet
```

1. Build the iOS target, install via `mcp__ios-simulator__install_app`, launch with bundle ID `com.luege.app`
2. Navigate through all affected screens using `ui_tap`, `ui_swipe`
3. Screenshot each screen with `ui_view` to verify correctness
4. Check: tap targets work, layouts render correctly, images are aligned, navigation flows end-to-end

App location: `~/Library/Developer/Xcode/DerivedData/Luege-*/Build/Products/Debug-iphonesimulator/Luege.app`

### Visual Verification on tvOS Simulator with idb

The iOS Simulator MCP tools do **not** support tvOS. Use `idb` (Facebook's iOS Development Bridge) and `xcrun simctl` instead.

**Simulator:** Apple TV 4K (3rd generation), UDID: `17DE6C53-47AB-4C2F-A9B2-3F54FAF04881`

```bash
# Boot, build, install, launch
xcrun simctl boot 17DE6C53-47AB-4C2F-A9B2-3F54FAF04881
xcodebuild build -workspace Luege.xcworkspace -scheme "Luege tvOS" \
  -destination "platform=tvOS Simulator,name=Apple TV 4K (3rd generation)" -quiet
xcrun simctl install 17DE6C53-47AB-4C2F-A9B2-3F54FAF04881 \
  ~/Library/Developer/Xcode/DerivedData/Luege-*/Build/Products/Debug-appletvsimulator/Luege.app
xcrun simctl launch 17DE6C53-47AB-4C2F-A9B2-3F54FAF04881 com.luege.app
```

**Screenshots:**
```bash
xcrun simctl io 17DE6C53-47AB-4C2F-A9B2-3F54FAF04881 screenshot /tmp/tvos_screen.png
```

**Navigation via idb remote key codes** (tvOS uses focus-based navigation, not touch):
```bash
# idb ui key <HID_KEYCODE> --udid <UDID>
idb ui key 40 --udid 17DE6C53-47AB-4C2F-A9B2-3F54FAF04881   # Select (Enter/Return)
idb ui key 41 --udid 17DE6C53-47AB-4C2F-A9B2-3F54FAF04881   # Menu/Back (Escape)
idb ui key 79 --udid 17DE6C53-47AB-4C2F-A9B2-3F54FAF04881   # Right arrow
idb ui key 80 --udid 17DE6C53-47AB-4C2F-A9B2-3F54FAF04881   # Left arrow
idb ui key 81 --udid 17DE6C53-47AB-4C2F-A9B2-3F54FAF04881   # Down arrow
idb ui key 82 --udid 17DE6C53-47AB-4C2F-A9B2-3F54FAF04881   # Up arrow
```

**Important notes:**
- Key codes are USB HID codes, **not** macOS virtual key codes
- `idb ui tap` sends touch events which exit the app on tvOS — use `idb ui key` instead
- First Select press focuses the element, second press activates it
- Accessibility tree via `idb ui describe-all` only returns the top-level Application node on tvOS

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
E1-001 through E1-003 (Discovery & connections), E2-001/E2-002 (Browsing), E3-001 through E3-004 (Playback), E4-001 through E4-003 (Library), E5-001 (Movie metadata), E6-001/E6-002 (Playback progress & watched tracking)

### Next Stories
- E5-002: Auto-fetch TV show metadata
- E6-003: Continue Watching row
- E7-002: Playback preferences (default audio track, subtitle styling)
