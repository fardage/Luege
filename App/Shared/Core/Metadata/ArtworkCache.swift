import Foundation

/// Disk-based cache for movie artwork
final class ArtworkCache: ArtworkCaching, ArtworkDownloading, @unchecked Sendable {
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.luege.artworkcache", attributes: .concurrent)
    private let session: URLSession

    /// Base directory for artwork cache
    private var cacheDirectory: URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("Luege/artwork", isDirectory: true)
    }

    /// Posters subdirectory
    private var postersDirectory: URL {
        cacheDirectory.appendingPathComponent("posters", isDirectory: true)
    }

    /// Backdrops subdirectory
    private var backdropsDirectory: URL {
        cacheDirectory.appendingPathComponent("backdrops", isDirectory: true)
    }

    /// Stills (episode thumbnails) subdirectory
    private var stillsDirectory: URL {
        cacheDirectory.appendingPathComponent("stills", isDirectory: true)
    }

    init(session: URLSession = .shared) {
        self.session = session
        ensureDirectoriesExist()
    }

    private func ensureDirectoriesExist() {
        try? fileManager.createDirectory(at: postersDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: backdropsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: stillsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Poster Caching

    func cachePoster(_ data: Data, for fileId: UUID, size: PosterSize) throws {
        try queue.sync(flags: .barrier) {
            let path = posterPath(for: fileId, size: size)
            try data.write(to: path, options: .atomic)
        }
    }

    func getCachedPoster(for fileId: UUID, size: PosterSize) -> Data? {
        queue.sync {
            let path = posterPath(for: fileId, size: size)
            return try? Data(contentsOf: path)
        }
    }

    func posterURL(for fileId: UUID, size: PosterSize) -> URL? {
        queue.sync {
            let path = posterPath(for: fileId, size: size)
            return fileManager.fileExists(atPath: path.path) ? path : nil
        }
    }

    private func posterPath(for fileId: UUID, size: PosterSize) -> URL {
        postersDirectory.appendingPathComponent("\(fileId.uuidString)_\(size.rawValue).jpg")
    }

    // MARK: - Backdrop Caching

    func cacheBackdrop(_ data: Data, for fileId: UUID, size: BackdropSize) throws {
        try queue.sync(flags: .barrier) {
            let path = backdropPath(for: fileId, size: size)
            try data.write(to: path, options: .atomic)
        }
    }

    func getCachedBackdrop(for fileId: UUID, size: BackdropSize) -> Data? {
        queue.sync {
            let path = backdropPath(for: fileId, size: size)
            return try? Data(contentsOf: path)
        }
    }

    func backdropURL(for fileId: UUID, size: BackdropSize) -> URL? {
        queue.sync {
            let path = backdropPath(for: fileId, size: size)
            return fileManager.fileExists(atPath: path.path) ? path : nil
        }
    }

    private func backdropPath(for fileId: UUID, size: BackdropSize) -> URL {
        backdropsDirectory.appendingPathComponent("\(fileId.uuidString)_\(size.rawValue).jpg")
    }

    // MARK: - Still Caching

    func cacheStill(_ data: Data, for fileId: UUID, size: StillSize) throws {
        try queue.sync(flags: .barrier) {
            let path = stillPath(for: fileId, size: size)
            try data.write(to: path, options: .atomic)
        }
    }

    func getCachedStill(for fileId: UUID, size: StillSize) -> Data? {
        queue.sync {
            let path = stillPath(for: fileId, size: size)
            return try? Data(contentsOf: path)
        }
    }

    func stillURL(for fileId: UUID, size: StillSize) -> URL? {
        queue.sync {
            let path = stillPath(for: fileId, size: size)
            return fileManager.fileExists(atPath: path.path) ? path : nil
        }
    }

    private func stillPath(for fileId: UUID, size: StillSize) -> URL {
        stillsDirectory.appendingPathComponent("\(fileId.uuidString)_\(size.rawValue).jpg")
    }

    // MARK: - Deletion

    func deleteArtwork(for fileId: UUID) throws {
        try queue.sync(flags: .barrier) {
            // Delete all poster sizes
            for size in PosterSize.allCases {
                let path = posterPath(for: fileId, size: size)
                if fileManager.fileExists(atPath: path.path) {
                    try fileManager.removeItem(at: path)
                }
            }

            // Delete all backdrop sizes
            for size in BackdropSize.allCases {
                let path = backdropPath(for: fileId, size: size)
                if fileManager.fileExists(atPath: path.path) {
                    try fileManager.removeItem(at: path)
                }
            }

            // Delete all still sizes
            for size in StillSize.allCases {
                let path = stillPath(for: fileId, size: size)
                if fileManager.fileExists(atPath: path.path) {
                    try fileManager.removeItem(at: path)
                }
            }
        }
    }

    func deleteAllArtwork() throws {
        try queue.sync(flags: .barrier) {
            if fileManager.fileExists(atPath: cacheDirectory.path) {
                try fileManager.removeItem(at: cacheDirectory)
            }
            ensureDirectoriesExist()
        }
    }

    // MARK: - Cache Size

    func cacheSize() throws -> Int64 {
        try queue.sync {
            var totalSize: Int64 = 0

            let enumerator = fileManager.enumerator(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }

            return totalSize
        }
    }

    // MARK: - Download and Cache

    /// Download and cache a poster image
    /// - Parameters:
    ///   - tmdbPath: The TMDb poster path (e.g., "/abc123.jpg")
    ///   - fileId: The library file ID
    ///   - size: The desired poster size
    func downloadAndCachePoster(tmdbPath: String, for fileId: UUID, size: PosterSize = .grid) async throws {
        guard let url = TMDbService.posterURL(path: tmdbPath, size: tmdbPosterSize(for: size)) else {
            throw MetadataError.cacheFailed("Invalid poster URL")
        }

        let data = try await downloadImage(from: url)
        try cachePoster(data, for: fileId, size: size)
    }

    /// Download and cache a backdrop image
    /// - Parameters:
    ///   - tmdbPath: The TMDb backdrop path (e.g., "/xyz789.jpg")
    ///   - fileId: The library file ID
    ///   - size: The desired backdrop size
    func downloadAndCacheBackdrop(tmdbPath: String, for fileId: UUID, size: BackdropSize = .default) async throws {
        guard let url = TMDbService.backdropURL(path: tmdbPath, size: tmdbBackdropSize(for: size)) else {
            throw MetadataError.cacheFailed("Invalid backdrop URL")
        }

        let data = try await downloadImage(from: url)
        try cacheBackdrop(data, for: fileId, size: size)
    }

    /// Download and cache a still (episode thumbnail) image
    /// - Parameters:
    ///   - tmdbPath: The TMDb still path (e.g., "/abc123.jpg")
    ///   - fileId: The library file ID
    ///   - size: The desired still size
    func downloadAndCacheStill(tmdbPath: String, for fileId: UUID, size: StillSize = .row) async throws {
        guard let url = TMDbService.stillURL(path: tmdbPath, size: tmdbStillSize(for: size)) else {
            throw MetadataError.cacheFailed("Invalid still URL")
        }

        let data = try await downloadImage(from: url)
        try cacheStill(data, for: fileId, size: size)
    }

    private func downloadImage(from url: URL) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw MetadataError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MetadataError.cacheFailed("Failed to download image")
        }

        return data
    }

    /// Convert our PosterSize to TMDb API size
    private func tmdbPosterSize(for size: PosterSize) -> TMDbService.PosterSize {
        switch size {
        case .w92: return .w92
        case .w154: return .w154
        case .w185: return .w185
        case .w342: return .w342
        case .w500: return .w500
        case .w780: return .w780
        case .original: return .original
        }
    }

    /// Convert our BackdropSize to TMDb API size
    private func tmdbBackdropSize(for size: BackdropSize) -> TMDbService.BackdropSize {
        switch size {
        case .w300: return .w300
        case .w780: return .w780
        case .w1280: return .w1280
        case .original: return .original
        }
    }

    /// Convert our StillSize to TMDb API size
    private func tmdbStillSize(for size: StillSize) -> TMDbService.StillSize {
        switch size {
        case .w92: return .w92
        case .w185: return .w185
        case .w300: return .w300
        case .original: return .original
        }
    }
}

// MARK: - Formatted Cache Size

extension ArtworkCache {
    /// Get formatted cache size string (e.g., "12.5 MB")
    func formattedCacheSize() throws -> String {
        let bytes = try cacheSize()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
