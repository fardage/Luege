import Foundation

/// Storage service for movie metadata using per-file JSON files
final class MetadataStorage: MetadataStoring, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.luege.metadatastorage", attributes: .concurrent)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Directory where movie metadata files are stored
    private var storageDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Luege/metadata", isDirectory: true)
    }

    /// Directory where TV show metadata is stored
    private var tvStorageDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Luege/metadata/tv", isDirectory: true)
    }

    /// Directory for TV episode metadata
    private var tvEpisodesDirectory: URL {
        tvStorageDirectory.appendingPathComponent("episodes", isDirectory: true)
    }

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Ensure storage directories exist
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: tvStorageDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: tvEpisodesDirectory, withIntermediateDirectories: true)
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

    // MARK: - TV Show Storage

    /// Get file path for TV show metadata
    private func tvShowPath(for tmdbId: Int) -> URL {
        tvStorageDirectory.appendingPathComponent("\(tmdbId).json")
    }

    /// Get file path for TV season metadata
    private func seasonPath(for seriesTmdbId: Int, seasonNumber: Int) -> URL {
        tvStorageDirectory.appendingPathComponent("\(seriesTmdbId)/season\(seasonNumber).json")
    }

    /// Get file path for TV episode metadata
    private func episodePath(for fileId: UUID) -> URL {
        tvEpisodesDirectory.appendingPathComponent("\(fileId.uuidString).json")
    }

    /// Save TV show metadata
    func saveTVShow(_ metadata: TVShowMetadata) throws {
        try queue.sync(flags: .barrier) {
            let path = tvShowPath(for: metadata.tmdbId)
            let data = try encoder.encode(metadata)
            try data.write(to: path, options: .atomic)
        }
    }

    /// Load TV show metadata
    func loadTVShow(forTmdbId tmdbId: Int) throws -> TVShowMetadata? {
        try queue.sync {
            let path = tvShowPath(for: tmdbId)
            guard fileManager.fileExists(atPath: path.path) else {
                return nil
            }
            let data = try Data(contentsOf: path)
            return try decoder.decode(TVShowMetadata.self, from: data)
        }
    }

    /// Check if TV show metadata exists
    func tvShowExists(forTmdbId tmdbId: Int) -> Bool {
        queue.sync {
            let path = tvShowPath(for: tmdbId)
            return fileManager.fileExists(atPath: path.path)
        }
    }

    /// Load all TV show metadata
    func loadAllTVShows() throws -> [Int: TVShowMetadata] {
        try queue.sync {
            var result: [Int: TVShowMetadata] = [:]

            guard fileManager.fileExists(atPath: tvStorageDirectory.path) else {
                return result
            }

            let files = try fileManager.contentsOfDirectory(
                at: tvStorageDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for file in files where file.pathExtension == "json" {
                let filename = file.deletingPathExtension().lastPathComponent
                guard let tmdbId = Int(filename) else { continue }

                if let data = try? Data(contentsOf: file),
                   let metadata = try? decoder.decode(TVShowMetadata.self, from: data) {
                    result[tmdbId] = metadata
                }
            }

            return result
        }
    }

    // MARK: - TV Season Storage

    /// Save TV season metadata
    func saveSeason(_ metadata: TVSeasonMetadata) throws {
        try queue.sync(flags: .barrier) {
            // Ensure series directory exists
            let seriesDir = tvStorageDirectory.appendingPathComponent("\(metadata.seriesTmdbId)", isDirectory: true)
            try? fileManager.createDirectory(at: seriesDir, withIntermediateDirectories: true)

            let path = seasonPath(for: metadata.seriesTmdbId, seasonNumber: metadata.seasonNumber)
            let data = try encoder.encode(metadata)
            try data.write(to: path, options: .atomic)
        }
    }

    /// Load TV season metadata
    func loadSeason(forSeriesId seriesTmdbId: Int, seasonNumber: Int) throws -> TVSeasonMetadata? {
        try queue.sync {
            let path = seasonPath(for: seriesTmdbId, seasonNumber: seasonNumber)
            guard fileManager.fileExists(atPath: path.path) else {
                return nil
            }
            let data = try Data(contentsOf: path)
            return try decoder.decode(TVSeasonMetadata.self, from: data)
        }
    }

    /// Load all seasons for a TV show
    func loadAllSeasons(forSeriesId seriesTmdbId: Int) throws -> [TVSeasonMetadata] {
        try queue.sync {
            let seriesDir = tvStorageDirectory.appendingPathComponent("\(seriesTmdbId)", isDirectory: true)
            guard fileManager.fileExists(atPath: seriesDir.path) else {
                return []
            }

            let files = try fileManager.contentsOfDirectory(
                at: seriesDir,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            var seasons: [TVSeasonMetadata] = []
            for file in files where file.pathExtension == "json" && file.lastPathComponent.hasPrefix("season") {
                if let data = try? Data(contentsOf: file),
                   let metadata = try? decoder.decode(TVSeasonMetadata.self, from: data) {
                    seasons.append(metadata)
                }
            }

            return seasons.sorted { $0.seasonNumber < $1.seasonNumber }
        }
    }

    // MARK: - TV Episode Storage

    /// Save TV episode metadata
    func saveEpisode(_ metadata: TVEpisodeMetadata) throws {
        try queue.sync(flags: .barrier) {
            let path = episodePath(for: metadata.id)
            let data = try encoder.encode(metadata)
            try data.write(to: path, options: .atomic)
        }
    }

    /// Load TV episode metadata
    func loadEpisode(forFileId fileId: UUID) throws -> TVEpisodeMetadata? {
        try queue.sync {
            let path = episodePath(for: fileId)
            guard fileManager.fileExists(atPath: path.path) else {
                return nil
            }
            let data = try Data(contentsOf: path)
            return try decoder.decode(TVEpisodeMetadata.self, from: data)
        }
    }

    /// Check if TV episode metadata exists
    func episodeExists(forFileId fileId: UUID) -> Bool {
        queue.sync {
            let path = episodePath(for: fileId)
            return fileManager.fileExists(atPath: path.path)
        }
    }

    /// Delete TV episode metadata
    func deleteEpisode(forFileId fileId: UUID) throws {
        try queue.sync(flags: .barrier) {
            let path = episodePath(for: fileId)
            if fileManager.fileExists(atPath: path.path) {
                try fileManager.removeItem(at: path)
            }
        }
    }

    /// Load all TV episode metadata
    func loadAllEpisodes() throws -> [UUID: TVEpisodeMetadata] {
        try queue.sync {
            var result: [UUID: TVEpisodeMetadata] = [:]

            guard fileManager.fileExists(atPath: tvEpisodesDirectory.path) else {
                return result
            }

            let files = try fileManager.contentsOfDirectory(
                at: tvEpisodesDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )

            for file in files where file.pathExtension == "json" {
                let filename = file.deletingPathExtension().lastPathComponent
                guard let fileId = UUID(uuidString: filename) else { continue }

                if let data = try? Data(contentsOf: file),
                   let metadata = try? decoder.decode(TVEpisodeMetadata.self, from: data) {
                    result[fileId] = metadata
                }
            }

            return result
        }
    }

    /// Load all episodes for a specific series
    func loadEpisodes(forSeriesId seriesTmdbId: Int) throws -> [TVEpisodeMetadata] {
        let allEpisodes = try loadAllEpisodes()
        return allEpisodes.values.filter { $0.seriesTmdbId == seriesTmdbId }
            .sorted { ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber) }
    }

    /// Delete all TV metadata
    func deleteAllTVMetadata() throws {
        try queue.sync(flags: .barrier) {
            if fileManager.fileExists(atPath: tvStorageDirectory.path) {
                try fileManager.removeItem(at: tvStorageDirectory)
            }
            // Recreate directories
            try? fileManager.createDirectory(at: tvStorageDirectory, withIntermediateDirectories: true)
            try? fileManager.createDirectory(at: tvEpisodesDirectory, withIntermediateDirectories: true)
        }
    }
}
