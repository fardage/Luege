# Luege

A tvOS/iOS media player for playing content directly from SMB network shares.

> [!NOTE]
> **This project is archived and no longer actively maintained.**
>
> This project was largely built with agentic coding tools (Claude Code). Some honest takeaways:
>
> - **The "hands-off" approach didn't work.** I tried treating the AI like a contractor with minimal review. The result: rough UI, suboptimal code, many unhandled edge cases.
> - **Verification is everything.** Giving the agent visual feedback via an iOS Simulator MCP server and `idb` for tvOS let it verify and iterate on its own changes. It was great at checking navigation flows, but bad at catching layout issues like alignment and padding. Without visual feedback, the agent writes code that technically works but falls apart on screen.
> - **Pre-commit hooks are essential.** The agent silently introduces regressions. Running unit tests on every commit catches what the agent breaks.
> - **Split platforms early.** Sharing views between iOS and tvOS created constant friction. With agents, maintaining separate views costs almost nothing since code generation is fast and cheap. Much better than fighting `#if os()` conditionals.
> - **iOS output is solid, tvOS less so.** The agent produces working iOS code with modern SwiftUI patterns. tvOS tripped it up repeatedly, likely due to far less training data for focus-based navigation and remote interaction.
> - **As a multiplier, it's impressive.** The tools shine when you stay engaged: reviewing code, testing manually, writing UI tests. I'll keep watching this space as the tooling matures.

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
