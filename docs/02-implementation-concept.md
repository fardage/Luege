# tvOS Media Player — Implementation Concept

## Overview

A serverless media player for Apple TV, iOS and iPadOS that plays content directly from SMB/NFS network shares with an Infuse-like library experience. Built with SwiftUI and VLCKit, using a hybrid architecture that applies Clean Architecture where it fits and reactive patterns where it doesn't.

**Core Principles:**
- No media server required — direct network share access
- Automatic metadata fetching with beautiful library presentation
- App Store distribution under MPL 2.0 license

## Key Dependencies

| Component | Library | License | Purpose |
|-----------|---------|---------|---------|
| Playback | MobileVLCKit / TVVLCKit | LGPL 2.1 | Media decoding & playback (via CocoaPods) |
| SMB Client | AMSMB2 | LGPL 2.1 | SMB2/3 file browsing |
| Network Discovery | Network.framework | Apple | Bonjour/mDNS share discovery |
| Metadata | TMDb API v3 | - | Movie/TV metadata (custom TMDbService) |
| Persistence | JSON files | - | Library storage (Application Support directory) |
| Credentials | Security.framework | Apple | Keychain for secure credential storage |

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Hybrid (Clean + Reactive) | Clean for discrete ops, reactive for continuous playback |
| Playback engine | MobileVLCKit / TVVLCKit | Best format support, LGPL compatible (via CocoaPods) |
| SMB library | AMSMB2 | Async/await, active maintenance |
| Metadata | TMDb API v3 | Free API, comprehensive coverage (custom service) |
| Persistence | JSON files | Simple, inspectable, no migration overhead |
| License | MPL 2.0 | App Store compatible, file-level copyleft |