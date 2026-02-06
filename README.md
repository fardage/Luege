# Luege

A tvOS/iOS media player for playing content directly from SMB network shares.

## Project Structure

```
Luege/
├── App/                        # iOS/tvOS application
│   ├── Shared/                # Shared SwiftUI code (Core/, Views/, ViewModels/)
│   ├── iOS/                   # iOS-specific files
│   ├── tvOS/                  # tvOS-specific files
│   ├── LuegeCoreTests/        # Unit tests
│   ├── LuegeIntegrationTests/ # Integration tests
│   ├── LuegeScreenshotTests/  # Visual regression tests
│   ├── project.yml            # XcodeGen project definition
│   └── Podfile                # CocoaPods (VLCKit)
├── Tools/                      # Development utilities
│   ├── docker/                # Docker test environment
│   └── scripts/               # Build and test scripts
├── docs/                       # Documentation
└── CLAUDE.md                   # Developer guide
```

## Quick Start

### Building the App

```bash
cd App && pod install           # Install CocoaPods dependencies
cd App && xcodegen generate     # Generate Xcode project
open Luege.xcworkspace          # Always use the workspace
```

### Running Tests

```bash
make test-unit          # Unit tests only
make test-integration   # Integration tests with Docker
make test               # All tests
```

### Development Workflow

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

## License

[Add license information]
