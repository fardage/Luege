import SwiftUI
import LuegeCore

@MainActor
final class FolderBrowserViewModel: ObservableObject {
    @Published private(set) var entries: [FileEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: BrowsingError?
    @Published private(set) var pathStack: [String] = []

    private let share: SavedShare
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

    /// Entries sorted with folders first, then alphabetically
    var sortedEntries: [FileEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isFolder != rhs.isFolder {
                return lhs.isFolder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
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
