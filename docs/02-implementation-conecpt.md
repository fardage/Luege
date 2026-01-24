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
| Playback | TVVLCKit | LGPL 2.1 | Media decoding & playback |
| SwiftUI VLC | VLCUI | MIT | SwiftUI wrapper for VLCKit |
| SMB Client | AMSMB2 | LGPL 2.1 | SMB2/3 file browsing |
| NFS Client | NFSKit | MIT | NFS file browsing |
| Metadata | TMDb Swift | Apache 2.0 | Movie/TV metadata |
| Persistence | CoreData | Apple | Library storage |

## Decision Log

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Hybrid (Clean + Reactive) | Clean for discrete ops, reactive for continuous playback |
| Playback engine | TVVLCKit | Best format support, LGPL compatible |
| SMB library | AMSMB2 | Async/await, active maintenance |
| Metadata | TMDb | Free API, comprehensive coverage |
| Persistence | CoreData | Native, proven, type-safe |
| License | MPL 2.0 | App Store compatible, file-level copyleft |