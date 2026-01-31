import Foundation

/// Main service for orchestrating movie metadata operations
@MainActor
final class MetadataService: ObservableObject {
    // MARK: - Published Properties

    /// Whether the TMDb API key is configured
    @Published private(set) var isAPIKeyConfigured: Bool = false

    /// Metadata fetch progress (current, total) for batch operations
    @Published private(set) var fetchProgress: (Int, Int)?

    /// Whether a batch fetch is in progress
    @Published private(set) var isFetching: Bool = false

    // MARK: - Dependencies

    private let filenameParser: FilenameParser
    private let fetcher: MetadataFetching
    private let storage: MetadataStoring
    private let artworkCache: ArtworkCaching
    private let artworkDownloader: ArtworkDownloading?
    private let apiKeyStorage: APIKeyStoring

    // MARK: - Cache

    private var metadataCache: [UUID: MovieMetadata] = [:]

    // MARK: - Initialization

    init(
        fetcher: MetadataFetching? = nil,
        storage: MetadataStoring? = nil,
        artworkCache: ArtworkCaching? = nil,
        artworkDownloader: ArtworkDownloading? = nil,
        apiKeyStorage: APIKeyStoring? = nil
    ) {
        let keyStorage = apiKeyStorage ?? TMDbAPIKeyStorage()
        self.apiKeyStorage = keyStorage
        self.fetcher = fetcher ?? TMDbService(apiKeyStore: keyStorage)
        self.storage = storage ?? MetadataStorage()
        let cache = artworkCache ?? ArtworkCache()
        self.artworkCache = cache
        self.artworkDownloader = artworkDownloader ?? (cache as? ArtworkDownloading)
        self.filenameParser = FilenameParser()

        // Check if API key is configured
        self.isAPIKeyConfigured = keyStorage.hasAPIKey()

        // Load cached metadata
        Task {
            await loadCachedMetadata()
        }
    }

    // MARK: - API Key Configuration

    /// Configure the TMDb API key
    func configureAPIKey(_ key: String) throws {
        try apiKeyStorage.storeAPIKey(key)
        isAPIKeyConfigured = true
    }

    /// Remove the TMDb API key
    func removeAPIKey() throws {
        try apiKeyStorage.deleteAPIKey()
        isAPIKeyConfigured = false
    }

    // MARK: - Metadata Fetching

    /// Fetch or load metadata for a single file
    func fetchMetadata(for file: LibraryFile, forceRefresh: Bool = false) async -> MetadataMatchResult {
        // Check cache first (unless force refresh)
        if !forceRefresh, let cached = metadataCache[file.id] {
            return .matched(cached)
        }

        // Check storage
        if !forceRefresh, let stored = try? storage.load(for: file.id) {
            metadataCache[file.id] = stored
            return .matched(stored)
        }

        // Need to fetch from TMDb
        guard isAPIKeyConfigured else {
            return .apiKeyMissing
        }

        // Parse filename
        let parseResult = filenameParser.parse(file.fileName)

        do {
            // Search TMDb
            let results = try await fetcher.searchMovies(title: parseResult.title, year: parseResult.year)

            guard let bestMatch = selectBestMatch(from: results, parseResult: parseResult) else {
                // No match found - save as unmatched
                let unmatched = MovieMetadata.unmatched(fileId: file.id, parseResult: parseResult)
                try? storage.save(unmatched, for: file.id)
                metadataCache[file.id] = unmatched
                return .notFound
            }

            // Fetch detailed info
            let details = try await fetcher.fetchMovieDetails(tmdbId: bestMatch.id)
            let metadata = MovieMetadata.from(details: details, fileId: file.id)

            // Save to storage and cache
            try storage.save(metadata, for: file.id)
            metadataCache[file.id] = metadata

            // Download poster in background
            if let posterPath = metadata.posterPath, let downloader = artworkDownloader {
                Task {
                    try? await downloader.downloadAndCachePoster(
                        tmdbPath: posterPath,
                        for: file.id,
                        size: .grid
                    )
                }
            }

            return .matched(metadata)

        } catch let error as MetadataError {
            return .error(error)
        } catch {
            return .error(.networkError(error.localizedDescription))
        }
    }

    /// Get cached metadata for a file (no network)
    func cachedMetadata(for file: LibraryFile) -> MovieMetadata? {
        if let cached = metadataCache[file.id] {
            return cached
        }

        if let stored = try? storage.load(for: file.id) {
            metadataCache[file.id] = stored
            return stored
        }

        return nil
    }

    /// Batch fetch metadata for multiple files
    func fetchMetadata(
        for files: [LibraryFile],
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async {
        guard isAPIKeyConfigured else { return }

        isFetching = true
        fetchProgress = (0, files.count)

        for (index, file) in files.enumerated() {
            // Skip if already cached
            if metadataCache[file.id] != nil { continue }
            if storage.exists(for: file.id) { continue }

            _ = await fetchMetadata(for: file)

            let progress = (index + 1, files.count)
            fetchProgress = progress
            progressHandler?(progress.0, progress.1)

            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
        }

        isFetching = false
        fetchProgress = nil
    }

    // MARK: - Cache Management

    /// Clear all cached metadata and artwork
    func clearCache() throws {
        try storage.deleteAll()
        try artworkCache.deleteAllArtwork()
        metadataCache.removeAll()
    }

    /// Get artwork cache size
    func artworkCacheSize() throws -> Int64 {
        try artworkCache.cacheSize()
    }

    /// Clear only artwork cache
    func clearArtworkCache() throws {
        try artworkCache.deleteAllArtwork()
    }

    /// Get formatted artwork cache size string
    func formattedArtworkCacheSize() throws -> String {
        let bytes = try artworkCache.cacheSize()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Artwork Access

    /// Get poster URL for a file (from cache if available)
    func posterURL(for fileId: UUID, size: PosterSize = .grid) -> URL? {
        artworkCache.posterURL(for: fileId, size: size)
    }

    /// Get backdrop URL for a file (from cache if available)
    func backdropURL(for fileId: UUID, size: BackdropSize = .default) -> URL? {
        artworkCache.backdropURL(for: fileId, size: size)
    }

    /// Ensure poster is cached for a file
    func ensurePosterCached(for metadata: MovieMetadata) async {
        guard let posterPath = metadata.posterPath,
              let downloader = artworkDownloader else { return }

        if artworkCache.posterURL(for: metadata.id, size: .grid) != nil {
            return
        }

        try? await downloader.downloadAndCachePoster(
            tmdbPath: posterPath,
            for: metadata.id,
            size: .grid
        )
    }

    // MARK: - Private

    private func loadCachedMetadata() async {
        do {
            metadataCache = try storage.loadAll()
        } catch {
            print("Failed to load cached metadata: \(error)")
        }
    }

    /// Select the best match from search results
    private func selectBestMatch(
        from results: [TMDbSearchResult],
        parseResult: FilenameParseResult
    ) -> TMDbSearchResult? {
        guard !results.isEmpty else { return nil }

        // If we have a year, prefer exact year match
        if let targetYear = parseResult.year {
            if let exactMatch = results.first(where: { $0.releaseYear == targetYear }) {
                return exactMatch
            }
            // Allow ±1 year tolerance
            if let closeMatch = results.first(where: {
                guard let year = $0.releaseYear else { return false }
                return abs(year - targetYear) <= 1
            }) {
                return closeMatch
            }
        }

        // Return first result (usually best by popularity)
        return results.first
    }
}
