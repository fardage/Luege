import Foundation

/// Main service for orchestrating movie and TV metadata operations
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
    private let tvFilenameParser: TVShowFilenameParser
    private let fetcher: MetadataFetching
    private let tvFetcher: TMDbService
    private let storage: MetadataStoring
    private let tvStorage: MetadataStorage  // Concrete type for TV-specific methods
    private let artworkCache: ArtworkCaching
    private let artworkDownloader: ArtworkDownloading?
    private let apiKeyStorage: APIKeyStoring

    // MARK: - Cache

    private var metadataCache: [UUID: MovieMetadata] = [:]
    private var tvShowCache: [Int: TVShowMetadata] = [:]
    private var tvEpisodeCache: [UUID: TVEpisodeMetadata] = [:]

    // MARK: - Initialization

    init(
        fetcher: MetadataFetching? = nil,
        storage: MetadataStoring? = nil,
        tvStorage: MetadataStorage? = nil,
        artworkCache: ArtworkCaching? = nil,
        artworkDownloader: ArtworkDownloading? = nil,
        apiKeyStorage: APIKeyStoring? = nil
    ) {
        let keyStorage = apiKeyStorage ?? TMDbAPIKeyStorage()
        self.apiKeyStorage = keyStorage
        let tmdbService = TMDbService(apiKeyStore: keyStorage)
        self.fetcher = fetcher ?? tmdbService
        self.tvFetcher = tmdbService
        let defaultStorage = MetadataStorage()
        self.storage = storage ?? defaultStorage
        self.tvStorage = tvStorage ?? defaultStorage
        let cache = artworkCache ?? ArtworkCache()
        self.artworkCache = cache
        self.artworkDownloader = artworkDownloader ?? (cache as? ArtworkDownloading)
        self.filenameParser = FilenameParser()
        self.tvFilenameParser = TVShowFilenameParser()

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
            tvShowCache = try tvStorage.loadAllTVShows()
            tvEpisodeCache = try tvStorage.loadAllEpisodes()
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

    // MARK: - TV Show Metadata

    /// Check if a file appears to be a TV show episode
    func isTVShow(_ filename: String) -> Bool {
        tvFilenameParser.isTVShow(filename)
    }

    /// Parse TV show info from filename
    func parseTVShow(_ filename: String) -> TVShowParseResult {
        tvFilenameParser.parse(filename)
    }

    /// Fetch or load episode metadata for a single file
    func fetchTVEpisodeMetadata(for file: LibraryFile, forceRefresh: Bool = false) async -> TVEpisodeMatchResult {
        // Check cache first (unless force refresh)
        if !forceRefresh, let cached = tvEpisodeCache[file.id] {
            return .matched(cached)
        }

        // Check storage
        if !forceRefresh, let stored = try? tvStorage.loadEpisode(forFileId: file.id) {
            tvEpisodeCache[file.id] = stored
            return .matched(stored)
        }

        // Need to fetch from TMDb
        guard isAPIKeyConfigured else {
            return .apiKeyMissing
        }

        // Parse filename
        let parseResult = tvFilenameParser.parse(file.fileName)

        guard parseResult.isValid else {
            // Not a valid TV show filename
            let unmatched = TVEpisodeMetadata.unmatched(fileId: file.id, parseResult: parseResult)
            try? tvStorage.saveEpisode(unmatched)
            tvEpisodeCache[file.id] = unmatched
            return .notFound
        }

        do {
            // Search for the TV show
            let searchResults = try await tvFetcher.searchTV(name: parseResult.showName)

            guard let bestMatch = selectBestTVMatch(from: searchResults, parseResult: parseResult) else {
                // No match found
                let unmatched = TVEpisodeMetadata.unmatched(fileId: file.id, parseResult: parseResult)
                try? tvStorage.saveEpisode(unmatched)
                tvEpisodeCache[file.id] = unmatched
                return .notFound
            }

            // Fetch and cache series details if not already cached
            let showMetadata: TVShowMetadata
            if let cached = tvShowCache[bestMatch.id] {
                showMetadata = cached
            } else {
                let seriesDetails = try await tvFetcher.fetchTVDetails(tmdbId: bestMatch.id)
                showMetadata = TVShowMetadata.from(details: seriesDetails)
                try? tvStorage.saveTVShow(showMetadata)
                tvShowCache[bestMatch.id] = showMetadata

                // Download series poster in background
                if let posterPath = showMetadata.posterPath, let downloader = artworkDownloader {
                    Task {
                        try? await downloader.downloadAndCachePoster(
                            tmdbPath: posterPath,
                            for: showMetadata.id,
                            size: .grid
                        )
                    }
                }
            }

            // Fetch season details to get episode info
            guard let seasonNumber = parseResult.season else {
                let unmatched = TVEpisodeMetadata.unmatched(fileId: file.id, parseResult: parseResult)
                try? tvStorage.saveEpisode(unmatched)
                tvEpisodeCache[file.id] = unmatched
                return .notFound
            }

            let seasonDetails = try await tvFetcher.fetchSeasonDetails(seriesId: bestMatch.id, seasonNumber: seasonNumber)

            // Save season metadata
            let seasonMetadata = TVSeasonMetadata.from(details: seasonDetails, seriesTmdbId: bestMatch.id)
            try? tvStorage.saveSeason(seasonMetadata)

            // Find the episode
            guard let episodeNumber = parseResult.episode,
                  let episode = seasonDetails.episodes?.first(where: { $0.episodeNumber == episodeNumber }) else {
                let unmatched = TVEpisodeMetadata.unmatched(fileId: file.id, parseResult: parseResult)
                try? tvStorage.saveEpisode(unmatched)
                tvEpisodeCache[file.id] = unmatched
                return .notFound
            }

            // Create episode metadata
            let episodeMetadata = TVEpisodeMetadata.from(
                episode: episode,
                fileId: file.id,
                seriesTmdbId: bestMatch.id
            )

            // Save to storage and cache
            try tvStorage.saveEpisode(episodeMetadata)
            tvEpisodeCache[file.id] = episodeMetadata

            // Download episode still in background
            if let stillPath = episodeMetadata.stillPath, let downloader = artworkDownloader {
                Task {
                    try? await downloader.downloadAndCacheStill(
                        tmdbPath: stillPath,
                        for: file.id,
                        size: .row
                    )
                }
            }

            return .matched(episodeMetadata)

        } catch let error as MetadataError {
            return .error(error)
        } catch {
            return .error(.networkError(error.localizedDescription))
        }
    }

    /// Get cached episode metadata for a file (no network)
    func cachedTVEpisodeMetadata(for file: LibraryFile) -> TVEpisodeMetadata? {
        if let cached = tvEpisodeCache[file.id] {
            return cached
        }

        if let stored = try? tvStorage.loadEpisode(forFileId: file.id) {
            tvEpisodeCache[file.id] = stored
            return stored
        }

        return nil
    }

    /// Get cached TV show metadata by TMDb ID
    func cachedTVShowMetadata(forTmdbId tmdbId: Int) -> TVShowMetadata? {
        if let cached = tvShowCache[tmdbId] {
            return cached
        }

        if let stored = try? tvStorage.loadTVShow(forTmdbId: tmdbId) {
            tvShowCache[tmdbId] = stored
            return stored
        }

        return nil
    }

    /// Get all cached TV shows
    func allCachedTVShows() -> [TVShowMetadata] {
        Array(tvShowCache.values).sorted { $0.name < $1.name }
    }

    /// Get all cached episodes for a TV show
    func cachedEpisodes(forSeriesId seriesTmdbId: Int) -> [TVEpisodeMetadata] {
        tvEpisodeCache.values
            .filter { $0.seriesTmdbId == seriesTmdbId }
            .sorted { ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber) }
    }

    /// Get cached seasons for a TV show
    func cachedSeasons(forSeriesId seriesTmdbId: Int) -> [TVSeasonMetadata] {
        (try? tvStorage.loadAllSeasons(forSeriesId: seriesTmdbId)) ?? []
    }

    /// Batch fetch TV episode metadata for multiple files
    func fetchTVMetadata(
        for files: [LibraryFile],
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async {
        guard isAPIKeyConfigured else { return }

        isFetching = true
        fetchProgress = (0, files.count)

        for (index, file) in files.enumerated() {
            // Skip if already cached
            if tvEpisodeCache[file.id] != nil { continue }
            if tvStorage.episodeExists(forFileId: file.id) { continue }

            _ = await fetchTVEpisodeMetadata(for: file)

            let progress = (index + 1, files.count)
            fetchProgress = progress
            progressHandler?(progress.0, progress.1)

            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
        }

        isFetching = false
        fetchProgress = nil
    }

    /// Get still URL for an episode (from cache if available)
    func stillURL(for fileId: UUID, size: StillSize = .row) -> URL? {
        artworkCache.stillURL(for: fileId, size: size)
    }

    /// Ensure still is cached for an episode
    func ensureStillCached(for metadata: TVEpisodeMetadata) async {
        guard let stillPath = metadata.stillPath,
              let downloader = artworkDownloader else { return }

        if artworkCache.stillURL(for: metadata.id, size: .row) != nil {
            return
        }

        try? await downloader.downloadAndCacheStill(
            tmdbPath: stillPath,
            for: metadata.id,
            size: .row
        )
    }

    /// Select the best TV show match from search results
    private func selectBestTVMatch(
        from results: [TMDbTVSearchResult],
        parseResult: TVShowParseResult
    ) -> TMDbTVSearchResult? {
        guard !results.isEmpty else { return nil }

        // Normalize the search name for comparison
        let normalizedSearch = parseResult.showName.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .trimmingCharacters(in: .whitespaces)

        // Try to find an exact name match first
        for result in results {
            let normalizedResult = result.name.lowercased()
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: ".", with: " ")
                .trimmingCharacters(in: .whitespaces)

            if normalizedResult == normalizedSearch {
                return result
            }
        }

        // Return first result (usually best by popularity)
        return results.first
    }
}

// MARK: - TV Episode Match Result

/// Result of attempting to match a file to TV episode metadata
enum TVEpisodeMatchResult: Sendable {
    /// Successfully matched with metadata
    case matched(TVEpisodeMetadata)
    /// No match found on TMDb
    case notFound
    /// API key not configured
    case apiKeyMissing
    /// Error occurred during matching
    case error(MetadataError)
}
