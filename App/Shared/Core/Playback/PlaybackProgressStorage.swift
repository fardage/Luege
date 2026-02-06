import Foundation

/// Protocol for persisting playback progress to disk
protocol PlaybackProgressStoring: Sendable {
    func save(_ progress: PlaybackProgress) throws
    func load(for fileId: UUID) throws -> PlaybackProgress?
    func delete(for fileId: UUID) throws
    func exists(for fileId: UUID) -> Bool
    func loadAll() throws -> [UUID: PlaybackProgress]
    func deleteAll() throws
}

/// File-based JSON storage for playback progress
final class PlaybackProgressStorage: PlaybackProgressStoring, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.luege.playbackprogressstorage", attributes: .concurrent)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var storageDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Luege/playback-progress", isDirectory: true)
    }

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }

    private func filePath(for fileId: UUID) -> URL {
        storageDirectory.appendingPathComponent("\(fileId.uuidString).json")
    }

    func save(_ progress: PlaybackProgress) throws {
        try queue.sync(flags: .barrier) {
            let path = filePath(for: progress.fileId)
            let data = try encoder.encode(progress)
            try data.write(to: path, options: .atomic)
        }
    }

    func load(for fileId: UUID) throws -> PlaybackProgress? {
        try queue.sync {
            let path = filePath(for: fileId)
            guard fileManager.fileExists(atPath: path.path) else {
                return nil
            }
            let data = try Data(contentsOf: path)
            return try decoder.decode(PlaybackProgress.self, from: data)
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

    func loadAll() throws -> [UUID: PlaybackProgress] {
        try queue.sync {
            var result: [UUID: PlaybackProgress] = [:]

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
                   let progress = try? decoder.decode(PlaybackProgress.self, from: data) {
                    result[fileId] = progress
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
