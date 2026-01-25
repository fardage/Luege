import Foundation

/// Service for storing share metadata as JSON in the file system
public final class FileShareStorage: ShareMetadataStoring, @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.luege.filestorage")

    /// Initialize with a custom storage location
    /// - Parameters:
    ///   - directory: Directory to store the shares file
    ///   - fileName: Name of the JSON file
    ///   - fileManager: FileManager instance (injectable for testing)
    public init(
        directory: URL? = nil,
        fileName: String = "saved-shares.json",
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

    public func saveAll(_ shares: [SavedShare]) throws {
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            data = try encoder.encode(shares)
        } catch {
            throw PersistenceError.encodingFailed(error.localizedDescription)
        }

        do {
            // Ensure parent directory exists
            let directory = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw PersistenceError.fileSystemError(error.localizedDescription)
        }
    }

    public func loadAll() throws -> [SavedShare] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw PersistenceError.fileSystemError(error.localizedDescription)
        }

        // Handle empty file
        if data.isEmpty {
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([SavedShare].self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(error.localizedDescription)
        }
    }

    public func deleteAll() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw PersistenceError.fileSystemError(error.localizedDescription)
        }
    }

    /// Get the storage file URL (for debugging/testing)
    public var storageURL: URL {
        fileURL
    }
}
