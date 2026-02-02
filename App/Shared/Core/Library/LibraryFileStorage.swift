import Foundation

/// Storage service for library file indexes using per-folder JSON files
final class LibraryFileStorage: LibraryFileStoring, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.luege.libraryfilestorage", attributes: .concurrent)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Directory where library file indexes are stored
    private var storageDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Luege/library-files", isDirectory: true)
    }

    init() {
        // Ensure storage directory exists
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    /// Get the file path for a folder's index
    private func filePath(for folderId: UUID) -> URL {
        storageDirectory.appendingPathComponent("\(folderId.uuidString).json")
    }

    func loadFiles(forFolder folderId: UUID) throws -> [LibraryFile] {
        try queue.sync {
            let path = filePath(for: folderId)
            guard fileManager.fileExists(atPath: path.path) else {
                return []
            }
            let data = try Data(contentsOf: path)
            return try decoder.decode([LibraryFile].self, from: data)
        }
    }

    func saveFiles(_ files: [LibraryFile], forFolder folderId: UUID) throws {
        try queue.sync(flags: .barrier) {
            let path = filePath(for: folderId)
            let data = try encoder.encode(files)
            try data.write(to: path, options: .atomic)
        }
    }

    func deleteFiles(forFolder folderId: UUID) throws {
        try queue.sync(flags: .barrier) {
            let path = filePath(for: folderId)
            if fileManager.fileExists(atPath: path.path) {
                try fileManager.removeItem(at: path)
            }
        }
    }
}
