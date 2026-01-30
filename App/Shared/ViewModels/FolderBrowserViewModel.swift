import SwiftUI

@MainActor
final class FolderBrowserViewModel: ObservableObject {
    @Published private(set) var entries: [FileEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: BrowsingError?
    @Published private(set) var pathStack: [String] = []
    @Published var showAllFiles = false

    /// Subtitles found in subtitle subfolders (sub, subs, Subs, Subtitles)
    @Published private(set) var subfolderSubtitles: [FileEntry] = []

    /// Common subtitle subfolder names to scan
    private static let subtitleFolderNames: Set<String> = ["sub", "subs", "subtitles"]

    /// Paths that are library folders (for badge display)
    @Published private(set) var libraryFolderPaths: Set<String> = []

    let share: SavedShare
    private let browser: any DirectoryBrowsing
    private let credentialProvider: () async throws -> ShareCredentials?

    /// Current path relative to share root
    var currentPath: String {
        pathStack.joined(separator: "/")
    }

    /// Breadcrumb components for navigation
    var breadcrumbs: [BreadcrumbItem] {
        var items = [BreadcrumbItem(name: share.displayName, pathIndex: -1)]
        for (index, component) in pathStack.enumerated() {
            items.append(BreadcrumbItem(name: component, pathIndex: index))
        }
        return items
    }

    /// Whether we can navigate back
    var canNavigateBack: Bool {
        !pathStack.isEmpty
    }

    /// Subtitle associations mapping video base names to subtitle entries
    /// Includes subtitles from both the current directory and subtitle subfolders
    var subtitleAssociations: [String: [FileEntry]] {
        var associations: [String: [FileEntry]] = [:]
        let videos = entries.filter { $0.isVideoFile }

        // Combine subtitles from current directory and subfolders
        let allSubtitles = entries.filter { $0.isSubtitleFile } + subfolderSubtitles

        for subtitle in allSubtitles {
            let subtitleBase = subtitle.baseFileName

            // Try to find matching video by checking if video base name matches
            // This handles cases like:
            // - "movie.srt" matches "movie.mkv"
            // - "movie.en.srt" matches "movie.mkv" (language suffix)
            for video in videos {
                let videoBase = video.baseFileName
                // Check if subtitle base starts with video base
                // or if they match exactly
                if subtitleBase == videoBase || subtitleBase.hasPrefix(videoBase + ".") {
                    associations[videoBase, default: []].append(subtitle)
                    break
                }
            }
        }

        return associations
    }

    /// Filtered and sorted entries based on showAllFiles toggle
    var filteredEntries: [FileEntry] {
        let videoBaseNames = Set(entries.filter { $0.isVideoFile }.map { $0.baseFileName })

        let filtered = entries.filter { entry in
            // Always show folders
            if entry.isFolder {
                return true
            }

            // Always show videos
            if entry.isVideoFile {
                return true
            }

            // Hide subtitle files that have a matching video
            if entry.isSubtitleFile {
                let subtitleBase = entry.baseFileName
                // Check if this subtitle matches any video
                for videoBase in videoBaseNames {
                    if subtitleBase == videoBase || subtitleBase.hasPrefix(videoBase + ".") {
                        return false
                    }
                }
                // Orphan subtitle: show only if showAllFiles is true
                return showAllFiles
            }

            // Other files: show only if showAllFiles is true
            return showAllFiles
        }

        // Apply existing sort (folders first, alphabetical)
        return filtered.sorted { lhs, rhs in
            if lhs.isFolder != rhs.isFolder {
                return lhs.isFolder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Entries sorted with folders first, then alphabetically (deprecated, use filteredEntries)
    var sortedEntries: [FileEntry] {
        filteredEntries
    }

    /// Get subtitle files associated with a video
    func subtitles(for video: FileEntry) -> [FileEntry] {
        guard video.isVideoFile else { return [] }
        return subtitleAssociations[video.baseFileName] ?? []
    }

    /// Check if a folder entry is in the library
    func isInLibrary(_ entry: FileEntry) -> Bool {
        guard entry.isFolder else { return false }
        return libraryFolderPaths.contains(fullPath(for: entry))
    }

    /// Get the full path for an entry
    func fullPath(for entry: FileEntry) -> String {
        currentPath.isEmpty ? entry.name : "\(currentPath)/\(entry.name)"
    }

    /// Update library paths from library service
    func updateLibraryPaths(from folders: [LibraryFolder]) {
        let paths = folders
            .filter { $0.shareId == share.id }
            .map { $0.path }
        libraryFolderPaths = Set(paths)
    }

    init(
        share: SavedShare,
        browser: any DirectoryBrowsing = SMBDirectoryBrowser(),
        credentialProvider: @escaping () async throws -> ShareCredentials?
    ) {
        self.share = share
        self.browser = browser
        self.credentialProvider = credentialProvider
    }

    /// Connect to the share and load root directory
    func connect() async {
        isLoading = true
        error = nil

        do {
            let credentials = try await credentialProvider()
            try await browser.connect(to: share, credentials: credentials)
            await loadCurrentDirectory()
        } catch let browsingError as BrowsingError {
            error = browsingError
            isLoading = false
        } catch {
            self.error = .unknown(error.localizedDescription)
            isLoading = false
        }
    }

    /// Navigate into a folder
    func navigateInto(_ entry: FileEntry) async {
        guard entry.isFolder else { return }

        pathStack.append(entry.name)
        await loadCurrentDirectory()
    }

    /// Navigate back to parent folder
    func navigateBack() async {
        guard canNavigateBack else { return }

        pathStack.removeLast()
        await loadCurrentDirectory()
    }

    /// Navigate to a specific path index in the breadcrumb
    /// - Parameter index: -1 for root, 0+ for path components
    func navigateTo(pathIndex: Int) async {
        if pathIndex < 0 {
            pathStack.removeAll()
        } else if pathIndex < pathStack.count - 1 {
            pathStack = Array(pathStack.prefix(pathIndex + 1))
        } else {
            // Already at this level
            return
        }
        await loadCurrentDirectory()
    }

    /// Refresh the current directory
    func refresh() async {
        await loadCurrentDirectory()
    }

    /// Disconnect from the share
    func disconnect() async {
        await browser.disconnect()
    }

    private func loadCurrentDirectory() async {
        isLoading = true
        error = nil
        subfolderSubtitles = []

        do {
            entries = try await browser.listDirectory(at: currentPath)

            // Scan subtitle subfolders for additional subtitles
            await loadSubtitleSubfolders()

            isLoading = false
        } catch let browsingError as BrowsingError {
            error = browsingError
            isLoading = false
        } catch {
            self.error = .unknown(error.localizedDescription)
            isLoading = false
        }
    }

    /// Scan common subtitle subfolders (sub, subs, Subtitles) for subtitle files
    private func loadSubtitleSubfolders() async {
        // Find subtitle folders in current directory
        let subtitleFolders = entries.filter { entry in
            entry.isFolder && Self.subtitleFolderNames.contains(entry.name.lowercased())
        }

        guard !subtitleFolders.isEmpty else { return }

        var foundSubtitles: [FileEntry] = []

        for folder in subtitleFolders {
            let folderPath = currentPath.isEmpty ? folder.name : "\(currentPath)/\(folder.name)"

            do {
                let folderContents = try await browser.listDirectory(at: folderPath)
                let subtitles = folderContents.filter { $0.isSubtitleFile }
                foundSubtitles.append(contentsOf: subtitles)
                print("[FolderBrowserVM] Found \(subtitles.count) subtitles in \(folder.name)/")
            } catch {
                // Silently ignore errors when scanning subtitle folders
                print("[FolderBrowserVM] Could not scan subtitle folder \(folder.name): \(error)")
            }
        }

        subfolderSubtitles = foundSubtitles
    }
}

/// Represents a breadcrumb navigation item
struct BreadcrumbItem: Identifiable {
    let name: String
    let pathIndex: Int

    var id: Int { pathIndex }
}
