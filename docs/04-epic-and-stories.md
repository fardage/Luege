# Media Player for Apple TV — Epics & User Stories

## User Story Template

```
**ID:** [EPIC]-[NUMBER]
**Title:** [Short descriptive title]

**As a** [type of user],
**I want** [goal/desire],
**So that** [benefit/value].

**Acceptance Criteria:**
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

**Notes:** [Technical considerations, edge cases, or design guidance]
```

---

## Epic Overview

| Epic | Name | Description |
|------|------|-------------|
| E1 | Network Discovery | Find and connect to SMB shares on the local network (NFS deferred) |
| E2 | File Browsing | Navigate folder structures with a TV-optimized interface |
| E3 | Video Playback | Stream video files directly without transcoding |
| E4 | Library Management | Organize files from multiple sources into a unified collection |
| E5 | Metadata & Artwork | Fetch and display movie/TV information automatically |
| E6 | Playback State | Track and resume viewing progress |
| E7 | Settings & Configuration | User preferences and share management |

---

## E1: Network Discovery

### E1-001: Auto-discover SMB network shares ✅
**As a** user launching the app for the first time,
**I want** the app to automatically find available SMB shares on my network,
**So that** I can start browsing without manually entering server addresses.

**Acceptance Criteria:**
- [x] App scans local network for SMB shares using mDNS/Bonjour
- [x] Discovered shares appear in a list within 10 seconds on typical home networks
- [x] Each discovered share shows hostname/IP and share name
- [x] User can trigger a manual rescan

**Implementation Notes:**
- Uses `NWBrowser` for Bonjour discovery of `_smb._tcp` services
- Uses AMSMB2 library for SMB2/3 share enumeration
- `NetworkDiscoveryService` orchestrates discovery with configurable timeout
- Docker-based test environment for integration testing

**Notes:** NFS support deferred to E1-004.

---

### E1-002: Manually add a share ✅
**As a** user whose share wasn't auto-discovered,
**I want** to manually enter connection details,
**So that** I can access shares on devices that don't broadcast.

**Acceptance Criteria:**
- [x] User can enter: protocol (SMB/NFS), hostname or IP, share path
- [x] Optional fields for username and password (SMB)
- [x] Connection is tested before saving
- [x] Clear error messages on connection failure
- [x] Manual shares appear alongside discovered shares

**Implementation Notes:**
- `ManualShareInput` model captures user input (protocol, host, share name, credentials)
- `ShareProtocol` enum supports SMB (NFS deferred to E1-004)
- `ShareCredentials` model for optional username/password authentication
- `ConnectionTesting` protocol with `SMBConnectionTester` implementation
- `ConnectionError` enum provides user-friendly error messages
- `NetworkDiscoveryService` extended with `addManualShare()` and `removeManualShare()`
- Manual shares tracked separately and merged in `allShares` computed property

---

### E1-003: Save and manage connections ✅
**As a** returning user,
**I want** my configured shares to be remembered,
**So that** I don't have to re-enter credentials each session.

**Acceptance Criteria:**
- [x] Credentials stored securely in Keychain
- [x] Saved shares auto-connect on app launch
- [x] User can edit or remove saved shares
- [x] Connection status indicator (online/offline) for each share

**Implementation Notes:**
- `KeychainService` uses Security.framework with `kSecAttrAccessibleAfterFirstUnlock` for tvOS compatibility
- `FileShareStorage` persists share metadata as JSON in Application Support directory
- `SavedShareStorageService` combines Keychain (credentials) and file storage (metadata)
- `SavedShare` model contains credential reference (UUID) without storing actual credentials
- `ConnectionStatusService` manages status checking for all tracked shares
- `SMBStatusChecker` uses existing `SMBConnectionTester` for connection validation
- `ConnectionStatus` enum: unknown, checking, online, offline(reason)
- `NetworkDiscoveryService` extended with persistence integration:
  - `loadSavedShares()` called on app launch
  - `saveShare()`, `updateSavedShare()`, `deleteSavedShare()` for CRUD
  - `refreshStatus()` and `refreshAllStatuses()` for status monitoring
  - Background status refresh on launch

---

### E1-004: Auto-discover NFS exports (Future)
**As a** user with NFS shares on my network,
**I want** the app to automatically find available NFS exports,
**So that** I can access content on Linux/Unix servers.

**Acceptance Criteria:**
- [ ] App scans for NFS exports via mDNS (`_nfs._tcp`)
- [ ] Discovered NFS exports appear alongside SMB shares
- [ ] Each export shows hostname/IP and export path

**Notes:** Deferred from E1-001 to simplify initial implementation. Consider NFSKit library.

---

## E2: File Browsing

### E2-001: Browse folder structure
**As a** user connected to a share,  
**I want** to navigate folders using my Apple TV remote,  
**So that** I can find and select videos to play.

**Acceptance Criteria:**
- [ ] Folders and files displayed in a grid or list view
- [ ] Folders show folder icon; video files show thumbnail or poster if available
- [ ] Swipe/click navigation with focus states
- [ ] Back button returns to parent folder
- [ ] Breadcrumb or path indicator shows current location

---

### E2-002: Filter to video files
**As a** user browsing folders,  
**I want** non-video files to be hidden or de-emphasized,  
**So that** the interface stays focused on playable content.

**Acceptance Criteria:**
- [ ] Recognized video extensions: MKV, MP4, AVI, MOV, WMV, M4V, TS, etc.
- [ ] Non-video files hidden by default
- [ ] Optional toggle to show all files
- [ ] Subtitle files (.srt, .ass, .sub) associated with their video, not shown separately

---

### E2-003: Sort and filter options
**As a** user with large folders,  
**I want** to sort files by name, date, or size,  
**So that** I can find content more easily.

**Acceptance Criteria:**
- [ ] Sort options: Name (A-Z, Z-A), Date modified, Size
- [ ] Current sort order persists per folder
- [ ] Quick access via menu button on remote

---

## E3: Video Playback

### E3-001: Play video files
**As a** user who selected a video,  
**I want** playback to start immediately,  
**So that** I can watch my content without delay.

**Acceptance Criteria:**
- [ ] Playback begins within 3 seconds for local network streams
- [ ] Standard transport controls: play, pause, seek, skip ±10s
- [ ] Swipe-to-seek gesture support
- [ ] Press Menu to exit playback and return to browser

---

### E3-002: Support common video formats
**As a** user with a diverse media collection,  
**I want** the app to play files regardless of container or codec,  
**So that** I don't need to re-encode my library.

**Acceptance Criteria:**
- [ ] Containers: MKV, MP4, AVI, MOV, WMV, M4V, TS, WEBM
- [ ] Video codecs: H.264, H.265/HEVC, VP9 (hardware-supported on Apple TV)
- [ ] Audio codecs: AAC, AC3, EAC3, DTS (passthrough), TrueHD, FLAC, MP3
- [ ] Graceful error message for unsupported codecs with codec name shown

**Notes:** Leverage AVFoundation and VLCKit/FFmpeg for broad compatibility.

---

### E3-003: Audio track selection
**As a** user watching a file with multiple audio tracks,  
**I want** to switch between audio tracks during playback,  
**So that** I can choose my preferred language or format.

**Acceptance Criteria:**
- [ ] Audio tracks listed by language and codec (e.g., "English - AC3 5.1")
- [ ] Accessible via swipe-down menu during playback
- [ ] Selection persists for the current file
- [ ] Default track preference configurable in settings

---

### E3-004: Subtitle support
**As a** user who needs subtitles,  
**I want** to enable embedded or external subtitle tracks,  
**So that** I can follow dialogue in any language.

**Acceptance Criteria:**
- [ ] Detect embedded subtitles (SRT, ASS, PGS in MKV)
- [ ] Detect external .srt/.ass files with matching filename
- [ ] Subtitle track selector in playback menu
- [ ] Basic styling options: size, color, background
- [ ] Subtitle delay adjustment (+/- sync)

---

## E4: Library Management

### E4-001: Add folders to library
**As a** user with organized media folders,  
**I want** to designate specific folders as "Movies" or "TV Shows,"  
**So that** content is categorized and enriched appropriately.

**Acceptance Criteria:**
- [ ] User can mark any folder as a library source
- [ ] Content type selection: Movies, TV Shows, Home Videos, Other
- [ ] Multiple folders can contribute to the same library
- [ ] Scan runs automatically on folder addition

---

### E4-002: Unified library view
**As a** user with files spread across multiple shares,  
**I want** a single "Library" view that aggregates all sources,  
**So that** I see my full collection in one place.

**Acceptance Criteria:**
- [ ] Library tab on home screen
- [ ] Content merged from all library folders
- [ ] Grouped by Movies / TV Shows / Other
- [ ] Duplicates (same title, same file) deduplicated

---

### E4-003: Scan and refresh library
**As a** user who added new files,  
**I want** the library to detect changes,  
**So that** new content appears without manual intervention.

**Acceptance Criteria:**
- [ ] Background scan on app launch
- [ ] Manual "Refresh Library" option
- [ ] Incremental scan (only check for changes)
- [ ] Removed files flagged or hidden, not deleted from library DB

---

## E5: Metadata & Artwork

### E5-001: Auto-fetch movie metadata
**As a** user viewing my movie library,  
**I want** posters, titles, and descriptions fetched automatically,  
**So that** the interface looks polished and informative.

**Acceptance Criteria:**
- [ ] Match files to TMDb (or similar) by filename parsing
- [ ] Fetch: poster, backdrop, title, year, runtime, genre, synopsis
- [ ] Display metadata in library grid and detail view
- [ ] Cache artwork locally for fast loading

**Notes:** Use TMDb API with attribution per their terms.

---

### E5-002: Auto-fetch TV show metadata
**As a** user with TV series,  
**I want** episodes grouped by show and season with episode info,  
**So that** I can easily navigate series.

**Acceptance Criteria:**
- [ ] Parse show name, season, episode from filename (e.g., "Show S01E03")
- [ ] Fetch series poster, episode thumbnails, episode titles
- [ ] Group episodes under Show → Season → Episode hierarchy
- [ ] Display episode synopsis and air date

---

### E5-003: Manual metadata correction
**As a** user with a mismatched file,  
**I want** to manually search and select the correct match,  
**So that** metadata is accurate.

**Acceptance Criteria:**
- [ ] "Fix Match" option on any library item
- [ ] Search TMDb by title
- [ ] Preview metadata before confirming
- [ ] Option to mark as "unmatched" to skip enrichment

---

## E6: Playback State

### E6-001: Remember playback position
**As a** user who paused a movie,  
**I want** playback to resume where I left off,  
**So that** I don't have to seek manually.

**Acceptance Criteria:**
- [ ] Position saved on pause, stop, or app exit
- [ ] "Resume" prompt when selecting a partially watched file
- [ ] Option to start from beginning instead
- [ ] Position persists across app sessions

---

### E6-002: Mark as watched/unwatched
**As a** user managing my library,  
**I want** to mark items as watched or unwatched,  
**So that** I know what I've seen.

**Acceptance Criteria:**
- [ ] Auto-mark as watched when >90% viewed
- [ ] Manual toggle in item options menu
- [ ] Visual indicator (checkmark/badge) on watched items
- [ ] Filter library by watched status

---

### E6-003: Continue Watching row
**As a** user returning to the app,  
**I want** to see in-progress videos on the home screen,  
**So that** I can quickly resume watching.

**Acceptance Criteria:**
- [ ] "Continue Watching" row shows items with saved position
- [ ] Sorted by last played date
- [ ] Shows progress bar indicator
- [ ] Remove from row option

---

## E7: Settings & Configuration

### E7-001: Manage saved shares
**As a** user with multiple network locations,  
**I want** a settings screen to view, edit, and remove shares,  
**So that** I can keep my connections organized.

**Acceptance Criteria:**
- [ ] List all saved shares with status
- [ ] Edit credentials, path, or nickname
- [ ] Delete share (with confirmation)
- [ ] Reorder or set default share

---

### E7-002: Playback preferences
**As a** a user with specific preferences,  
**I want** to configure default playback settings,  
**So that** the app behaves the way I like.

**Acceptance Criteria:**
- [ ] Default audio language preference
- [ ] Default subtitle language (or off)
- [ ] Subtitle appearance settings
- [ ] Skip intro/credits (if detectable) toggle

---

### E7-003: Library and metadata settings
**As a** user who wants control over metadata,  
**I want** to configure how the library fetches and displays data,  
**So that** I can balance richness vs. privacy/bandwidth.

**Acceptance Criteria:**
- [ ] Toggle auto-fetch metadata on/off
- [ ] Clear metadata cache
- [ ] Preferred metadata language
- [ ] Content rating filter (for kids profiles, if applicable)

---

## Suggested MVP Scope

For an initial release, consider prioritizing:

1. **E1:** Network Discovery (all stories)
2. **E2:** File Browsing (E2-001, E2-002)
3. **E3:** Video Playback (E3-001, E3-002, E3-004)
4. **E6:** Playback State (E6-001 only)

This delivers the core loop: connect → browse → play → resume — without the complexity of library management and metadata fetching, which can follow in v1.1.

---

## Backlog Candidates (Post-MVP)

- Parental controls / profiles
- AirPlay 2 speaker output selection
- Picture-in-picture support
- Siri integration ("Play the next episode of…")
- Trakt.tv scrobbling integration
- Customizable home screen layout
- Video chapter support
- HDR / Dolby Vision metadata passthrough