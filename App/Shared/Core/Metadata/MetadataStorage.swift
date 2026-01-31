import Foundation

/// Storage service for movie metadata using per-file JSON files
final class MetadataStorage: MetadataStoring, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.luege.metadatastorage", attributes: .concurrent)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Directory where metadata files are stored
    private var storageDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Luege/metadata", isDirectory: true)
    }

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Ensure storage directory exists
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    /// Get the file path for a metadata file
    private func filePath(for fileId: UUID) -> URL {
        storageDirectory.appendingPathComponent("\(fileId.uuidString).json")
    }

    func save(_ metadata: MovieMetadata, for fileId: UUID) throws {
        try queue.sync(flags: .barrier) {
            let path = filePath(for: fileId)
            let data = try encoder.encode(metadata)
            try data.write(to: path, options: .atomic)
        }
    }

    func load(for fileId: UUID) throws -> MovieMetadata? {
        try queue.sync {
            let path = filePath(for: fileId)
            guard fileManager.fileExists(atPath: path.path) else {
                return nil
            }
            let data = try Data(contentsOf: path)
            return try decoder.decode(MovieMetadata.self, from: data)
        }
    }

    func delete(for fileId: UUID) throws {
        try queue.sync(flags: .barrier) {
            let path = filePath(for: fileId)
            if fileManager.fileExists(atPath: path.path) {
                try fileManager.removeItem(at: path)
            }
        }
    }

    func exists(for fileId: UUID) -> Bool {
        queue.sync {
            let path = filePath(for: fileId)
            return fileManager.fileExists(atPath: path.path)
        }
    }

    func loadAll() throws -> [UUID: MovieMetadata] {
        try queue.sync {
            var result: [UUID: MovieMetadata] = [:]

            guard fileManager.fileExists(atPath: storageDirectory.path) else {
                return result
            }

            let files = try fileManager.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for file in files where file.pathExtension == "json" {
                let filename = file.deletingPathExtension().lastPathComponent
                guard let fileId = UUID(uuidString: filename) else { continue }

                if let data = try? Data(contentsOf: file),
                   let metadata = try? decoder.decode(MovieMetadata.self, from: data) {
                    result[fileId] = metadata
                }
            }

            return result
        }
    }

    func deleteAll() throws {
        try queue.sync(flags: .barrier) {
            guard fileManager.fileExists(atPath: storageDirectory.path) else { return }

            let files = try fileManager.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for file in files where file.pathExtension == "json" {
                try fileManager.removeItem(at: file)
            }
        }
    }
}
