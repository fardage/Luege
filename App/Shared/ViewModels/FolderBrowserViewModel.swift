import SwiftUI

@MainActor
final class FolderBrowserViewModel: ObservableObject {
    @Published private(set) var entries: [FileEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: BrowsingError?
    @Published private(set) var pathStack: [String] = []
    @Published var showAllFiles = false

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

    /// Filtered and sorted entries based on showAllFiles toggle
    var filteredEntries: [FileEntry] {
        let filtered = entries.filter { entry in
            // Always show folders
            if entry.isFolder {
                return true
            }

            // Always show videos
            if entry.isVideoFile {
                return true
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
        initialPath: String = "",
        browser: any DirectoryBrowsing = SMBDirectoryBrowser(),
        credentialProvider: @escaping () async throws -> ShareCredentials?
    ) {
        self.share = share
        self.browser = browser
        self.credentialProvider = credentialProvider

        // Parse initial path into path stack
        if !initialPath.isEmpty {
            self.pathStack = initialPath.split(separator: "/").map(String.init)
        }
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

        do {
            entries = try await browser.listDirectory(at: currentPath)
            isLoading = false
        } catch let browsingError as BrowsingError {
            error = browsingError
            isLoading = false
        } catch {
            self.error = .unknown(error.localizedDescription)
            isLoading = false
        }
    }
}

/// Represents a breadcrumb navigation item
struct BreadcrumbItem: Identifiable {
    let name: String
    let pathIndex: Int

    var id: Int { pathIndex }
}
