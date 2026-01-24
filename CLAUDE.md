# Luege - Development Guide

## Project Overview

Luege is a tvOS/iOS media player for playing content directly from SMB network shares. Built with SwiftUI and AMSMB2, targeting Apple TV, iPhone, and iPad.

**Key Technologies:**
- Swift Package Manager
- SwiftUI (native-first approach)
- AMSMB2 for SMB2/3 protocol
- Network.framework for Bonjour/mDNS discovery

## Development Workflow

### Story Implementation Cycle

1. **Read the story** from `docs/04-epic-and-stories.md`
2. **Plan the implementation** - create protocol-based design for testability
3. **Implement core logic** in `Sources/LuegeCore/`
4. **Write unit tests** with mocks in `Tests/LuegeCoreTests/`
5. **Write integration tests** in `Tests/LuegeIntegrationTests/`
6. **Verify with Docker test environment**
7. **Update story status** in docs (mark acceptance criteria as complete)
8. **Commit with descriptive message**

### Running Tests

```bash
# Unit tests (no network required)
swift test --filter LuegeCoreTests

# Integration tests with Docker
./scripts/start-test-server.sh
LUEGE_TEST_SMB_SERVER=localhost swift test --filter LuegeIntegrationTests
./scripts/stop-test-server.sh

# All tests
swift test
```

### Docker Test Environment

The project includes a Docker-based Samba server for integration testing:

```bash
./scripts/start-test-server.sh   # Start SMB server (localhost:445)
./scripts/stop-test-server.sh    # Stop SMB server
./scripts/run-integration-tests.sh  # Start + run tests
```

Test shares: `TestShare`, `Movies`, `Music` (guest:guest credentials)

## Code Architecture

### Directory Structure

```
Sources/LuegeCore/
├── Discovery/           # Network discovery components
│   ├── DiscoveryProtocols.swift    # Protocol definitions
│   ├── BonjourBrowser.swift        # mDNS service discovery
│   ├── SMBShareEnumerator.swift    # SMB share listing
│   └── NetworkDiscoveryService.swift # Main orchestrator
└── Models/
    └── DiscoveredShare.swift       # Data models

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
- [ ] Tests pass
- [ ] Code reviewed for security issues

## Current Status

### Completed Stories
- ✅ E1-001: Auto-discover SMB network shares

### Next Stories
- E1-002: Manually add a share
- E1-003: Save and manage connections
- E2-001: Browse folder structure
