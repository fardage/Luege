import Foundation

/// Service for storing library folder metadata as JSON in the file system
final class LibraryFolderStorage: LibraryFolderStoring, @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.luege.librarystorage")

    /// Initialize with a custom storage location
    /// - Parameters:
    ///   - directory: Directory to store the library file
    ///   - fileName: Name of the JSON file
    ///   - fileManager: FileManager instance (injectable for testing)
    init(
        directory: URL? = nil,
        fileName: String = "library-folders.json",
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager

        if let directory = directory {
            self.fileURL = directory.appendingPathComponent(fileName)
        } else {
            // Use Application Support directory
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDirectory = appSupport.appendingPathComponent("Luege", isDirectory: true)

            // Create directory if needed
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

            self.fileURL = appDirectory.appendingPathComponent(fileName)
        }
    }

    func saveAll(_ folders: [LibraryFolder]) throws {
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            data = try encoder.encode(folders)
        } catch {
            throw LibraryError.storageFailed(error.localizedDescription)
        }

        do {
            // Ensure parent directory exists
            let directory = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw LibraryError.storageFailed(error.localizedDescription)
        }
    }

    func loadAll() throws -> [LibraryFolder] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw LibraryError.storageFailed(error.localizedDescription)
        }

        // Handle empty file
        if data.isEmpty {
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([LibraryFolder].self, from: data)
        } catch {
            throw LibraryError.storageFailed(error.localizedDescription)
        }
    }

    func deleteAll() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw LibraryError.storageFailed(error.localizedDescription)
        }
    }

    /// Get the storage file URL (for debugging/testing)
    var storageURL: URL {
        fileURL
    }
}
