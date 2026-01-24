# Design System Brief — Luege for Apple TV

## Overview

**Product:** Luege — free, open-source media player for Apple TV  
**Platform:** tvOS, iOS & iPadOS
**Design Philosophy:** Native-first, SwiftUI-first — use SwiftUI components and Apple conventions wherever possible

This is not a custom design system. The goal is to configure and compose native SwiftUI components to match Apple's own apps (TV, Music, Photos). Custom design only fills gaps where no native solution exists.

---

## 1. Design Principles

### Native First
1. **Use system components** — Don't redesign what SwiftUI provides
2. **Respect platform conventions** — Users already know how tvOS works
3. **Leverage built-in behaviors** — Focus engine, parallax, press states come free
4. **SF Symbols only** — No custom icon sets
5. **System colors and fonts** — Dynamic, accessible by default

### Benefits of This Approach
- Automatic Dark Mode support
- Automatic accessibility (VoiceOver, Bold Text, Reduce Motion)
- Faster development — less custom UI code
- Feels familiar to Apple TV users
- Future-proof as tvOS evolves

---

## 2. Native SwiftUI Components to Use

### Navigation & Structure

| Need | SwiftUI Solution |
|------|------------------|
| Top-level navigation | `TabView` — standard tab bar at top |
| Hierarchical navigation | `NavigationStack` — automatic back button handling |
| Page header | `.navigationTitle()` with `.large` display mode |

**Do not design:** Custom tab bars, navigation chrome, or back buttons.

### Content Grids & Lists

| Need | SwiftUI Solution |
|------|------------------|
| Poster grid (movies) | `LazyVGrid` with adaptive columns |
| Horizontal shelf | `ScrollView(.horizontal)` with `LazyHStack` |
| Episode/file list | `List` with standard row styles |
| Grouped settings | `List` with `.insetGrouped` style (via `Form`) |

**Layout patterns to follow:**
- Apple TV app "Watch Now" — hero + horizontal shelves
- Apple TV app "Library" — grid of poster cards
- Settings app — grouped form

### Cards & Buttons

| Need | SwiftUI Solution |
|------|------------------|
| Movie/show poster | `Button` with `.card` or `.cardButton` style |
| Focusable card | `.focusable()` modifier or `Button` |
| Action button | `Button` with `.borderedProminent` style |
| Secondary button | `Button` with `.bordered` style |

**Button styles on tvOS provide:**
- Automatic focus behavior (lift, shadow)
- Press state animations
- Parallax effect on card buttons

**Do not design:** Custom focus states, shadows, or press animations.

### Media Playback

| Need | SwiftUI Solution |
|------|------------------|
| Video player | `VideoPlayer` (AVKit) for simple cases |
| Full player UI | Wrap `AVPlayerViewController` via `UIViewControllerRepresentable` |
| Transport controls | Built into AVPlayerViewController |
| Info panel (swipe down) | `AVPlayerViewController.customInfoViewControllers` |

**AVPlayerViewController provides:**
- Standard play/pause/seek controls
- Swipe-to-scrub with thumbnail preview
- Info tab (swipe down)
- Audio & subtitle track selection
- Picture-in-Picture support

**Designer role:** Specify what metadata appears in the Info panel, not how controls look.

### Inputs & Selection

| Need | SwiftUI Solution |
|------|------------------|
| Buttons | `Button` with system styles |
| Toggles | `Toggle` |
| Segmented picker | `Picker` with `.segmented` style |
| Single selection list | `List` with `selection` binding |
| Text input | `TextField` (invokes system keyboard) |
| Search | `.searchable()` modifier |

**Do not design:** Button shapes, toggle appearances, or keyboard UI.

### Alerts & Feedback

| Need | SwiftUI Solution |
|------|------------------|
| Confirmation dialog | `.alert()` modifier |
| Action sheet | `.confirmationDialog()` modifier |
| Loading | `ProgressView()` |
| Determinate progress | `ProgressView(value:total:)` |

---

### What NOT to Build

- Button styles (use system)
- Typography scale (use system)
- Color palette (use system colors)
- Focus states (automatic)
- Navigation components (use system)
- Player controls (use AVPlayerViewController)
- Keyboard UI (use system)
- Alert dialogs (use system)
- Onboarding screens (not needed)

---

## 5. Reference: System Colors & Typography

### System Colors (Auto Dark Mode)

Use SwiftUI semantic colors:

| Use Case | SwiftUI Color |
|----------|---------------|
| Primary text | `.primary` |
| Secondary text | `.secondary` |
| Background | Default (no modifier needed) |
| Accent / tint | `.accentColor` / `.tint(.blue)` |
| Destructive | `.red` |
| Success | `.green` |

### System Typography

Use SwiftUI font styles:

| Style | Use Case |
|-------|----------|
| `.largeTitle` | Screen titles |
| `.title` | Section headers |
| `.title2` | Card titles |
| `.title3` | Subsection headers |
| `.headline` | Emphasized body text |
| `.body` | Primary content |
| `.callout` | Secondary content |
| `.caption` | Metadata, timestamps |
| `.caption2` | Tertiary info |

**No custom fonts.** SF Pro is the system default and optimized for TV.

---

## 6. Screen-by-Screen Guidance

### Home Screen
- `ScrollView` with `LazyVStack` of horizontal shelves
- **Continue Watching:** First shelf, card buttons with progress overlay
- **Recently Added:** Second shelf
- No hero banner for MVP — keep it simple
- Reference: Apple TV app "Watch Now" tab

### Library Screen
- `TabView` or `Picker` for Movies / TV Shows
- `LazyVGrid` of poster card buttons
- `.searchable()` for filtering
- Reference: Apple TV app "Library" tab

### Browse Screen (File Browser)
- `LazyVGrid` of folder/file cards
- `.navigationTitle()` shows current path
- Folders use SF Symbol `folder.fill`
- Video files show thumbnail if available, else `film` symbol
- Reference: Files app, Photos app folder view

### Detail Screen
- `ZStack` with blurred artwork background (`.background(.ultraThinMaterial)`)
- `HStack`: Poster image on left, metadata on right
- Title, year, runtime, genre, synopsis using system fonts
- `Button("Play")` with `.borderedProminent` style
- "Resume from X:XX" button if partially watched
- Episodes list (for TV shows) in `List` below
- Reference: Apple TV app movie/show detail

### Video Player
- Wrap `AVPlayerViewController` via `UIViewControllerRepresentable`
- Custom info panel showing: file info, audio tracks, subtitle tracks
- Reference: Any video in Apple TV app

### Settings Screen
- `Form` (renders as grouped list on tvOS)
- **Sections:**
  - Shares (list of saved connections)
  - Library (manage library folders, refresh)
  - Playback (default audio/subtitle language)
  - About (version, licenses, credits)
- Reference: Settings app

### Add Share Screen
- `Form` with input fields
- Fields: Protocol `Picker`, Host `TextField`, Path `TextField`, Username `TextField`, Password `SecureField`
- "Test Connection" `Button`
- `.toolbar` with "Save" button
- Reference: Any system settings input screen

### Empty States
When there's no content, show centered message with SF Symbol and action:

| Screen | Empty State |
|--------|-------------|
| Home (no shares) | `externaldrive.badge.wifi` + "Add a network share to get started" + button |
| Library (no items) | `film` + "Add folders to your library" + button |
| Browse (empty folder) | `folder` + "This folder is empty" |
| Continue Watching | Don't show the shelf at all |

---

## 7. Apple Documentation (Required Reading)

| Resource | Link |
|----------|------|
| tvOS Human Interface Guidelines | https://developer.apple.com/design/human-interface-guidelines/designing-for-tvos |
| SwiftUI on tvOS | https://developer.apple.com/documentation/swiftui/bringing-your-app-to-apple-tv |
| Focus and Navigation | https://developer.apple.com/documentation/swiftui/focus |
| Button Styles on tvOS | https://developer.apple.com/documentation/swiftui/buttonstyle |
| AVPlayerViewController | https://developer.apple.com/documentation/avkit/avplayerviewcontroller |
| SF Symbols | https://developer.apple.com/sf-symbols/ |
| Top Shelf Content | https://developer.apple.com/documentation/tvservices/tvtopshelfcontentprovider |

---

## 8. Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **App tint color** | System blue (`.blue`) | Maximum native consistency; works well against dark backgrounds and colorful poster art. No reason to deviate from platform conventions. |
| **App name** | Luege | Swiss German for "to watch" — distinctive, meaningful, and personal. |
| **Top shelf behavior** | Dynamic "Continue Watching" | More useful than static image; matches Apple TV app behavior; provides quick access to resume content directly from the home screen. |
| **Onboarding** | None | Drop users directly into share discovery. The app should be self-explanatory. Empty states with clear CTAs handle first-run guidance. If it needs onboarding, the UI has failed. |