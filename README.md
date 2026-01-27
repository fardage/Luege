# Luege

A tvOS/iOS media player for playing content directly from SMB network shares.

## Project Structure

```
Luege/
├── Sources/LuegeCore/          # Core business logic (SPM library)
├── Tests/                      # Unit and integration tests
├── App/                        # iOS/tvOS application
│   ├── Luege.xcodeproj/       # Xcode project
│   ├── Shared/                # Shared SwiftUI code
│   ├── iOS/                   # iOS-specific files
│   └── tvOS/                  # tvOS-specific files
├── Tools/                      # Development utilities
│   ├── docker/                # Docker test environment
│   └── scripts/               # Build and test scripts
├── docs/                       # Documentation
└── CLAUDE.md                   # Developer guide
```

## Quick Start

### Running Tests

```bash
# Unit tests only
make test-unit

# Integration tests with Docker
make test-integration

# All tests
make test
```

### Development Workflow

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines, including:
- Story implementation cycle
- Testing strategy
- Pre-commit hooks setup
- XcodeGen usage
- Docker test environment

## Building the App

1. Generate Xcode project:
   ```bash
   cd App && xcodegen generate
   ```

2. Open workspace in Xcode:
   ```bash
   open Luege.xcworkspace
   ```

   Note: Use the workspace (not `App/Luege.xcodeproj`) to edit both the app and LuegeCore library in a single window.

3. Build for iOS or tvOS targets

## License

[Add license information]
