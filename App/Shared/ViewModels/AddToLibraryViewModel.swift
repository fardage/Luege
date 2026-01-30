import Foundation

@MainActor
final class AddToLibraryViewModel: ObservableObject {
    @Published var selectedContentType: LibraryContentType = .movies
    @Published var displayName: String = ""
    @Published var isAdding = false
    @Published var error: LibraryError?

    let folderPath: String
    let folderName: String
    let share: SavedShare

    private let libraryService: LibraryService
    private let credentialProvider: () async throws -> ShareCredentials?

    init(
        folderPath: String,
        folderName: String,
        share: SavedShare,
        libraryService: LibraryService,
        credentialProvider: @escaping () async throws -> ShareCredentials?
    ) {
        self.folderPath = folderPath
        self.folderName = folderName
        self.share = share
        self.libraryService = libraryService
        self.credentialProvider = credentialProvider
        self.displayName = folderName
    }

    /// Add the folder to the library
    /// - Returns: true if successful
    func addToLibrary() async -> Bool {
        isAdding = true
        error = nil

        do {
            let credentials = try await credentialProvider()
            try await libraryService.addFolder(
                path: folderPath,
                share: share,
                contentType: selectedContentType,
                displayName: displayName.isEmpty ? nil : displayName,
                credentials: credentials
            )
            isAdding = false
            return true
        } catch let libraryError as LibraryError {
            error = libraryError
            isAdding = false
            return false
        } catch {
            self.error = .storageFailed(error.localizedDescription)
            isAdding = false
            return false
        }
    }

    /// Check if the folder is already in the library
    var isAlreadyInLibrary: Bool {
        libraryService.isInLibrary(path: folderPath, shareId: share.id)
    }
}
