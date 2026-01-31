import Foundation

// MARK: - API Key Storage

/// Protocol for storing and retrieving the TMDb API key
protocol APIKeyStoring: Sendable {
    /// Store the API key
    func storeAPIKey(_ key: String) throws

    /// Retrieve the stored API key
    func retrieveAPIKey() throws -> String?

    /// Delete the stored API key
    func deleteAPIKey() throws

    /// Check if an API key is stored
    func hasAPIKey() -> Bool
}

// MARK: - Metadata Fetching

/// Protocol for fetching movie metadata from TMDb
protocol MetadataFetching: Sendable {
    /// Search for movies matching the given title and optional year
    /// - Parameters:
    ///   - title: The movie title to search for
    ///   - year: Optional release year to narrow results
    /// - Returns: Array of search results
    func searchMovies(title: String, year: Int?) async throws -> [TMDbSearchResult]

    /// Fetch detailed movie information by TMDb ID
    /// - Parameter tmdbId: The TMDb movie ID
    /// - Returns: Detailed movie information
    func fetchMovieDetails(tmdbId: Int) async throws -> TMDbMovieDetails
}

// MARK: - Metadata Storage

/// Protocol for persisting movie metadata to disk
protocol MetadataStoring: Sendable {
    /// Save metadata for a library file
    /// - Parameters:
    ///   - metadata: The metadata to save
    ///   - fileId: The library file ID
    func save(_ metadata: MovieMetadata, for fileId: UUID) throws

    /// Load metadata for a library file
    /// - Parameter fileId: The library file ID
    /// - Returns: The stored metadata, or nil if not found
    func load(for fileId: UUID) throws -> MovieMetadata?

    /// Delete metadata for a library file
    /// - Parameter fileId: The library file ID
    func delete(for fileId: UUID) throws

    /// Check if metadata exists for a library file
    /// - Parameter fileId: The library file ID
    /// - Returns: true if metadata exists
    func exists(for fileId: UUID) -> Bool

    /// Load all stored metadata
    /// - Returns: Dictionary mapping file IDs to metadata
    func loadAll() throws -> [UUID: MovieMetadata]

    /// Delete all stored metadata
    func deleteAll() throws
}

// MARK: - Metadata Matching

/// Result of attempting to match a file to movie metadata
enum MetadataMatchResult: Sendable {
    /// Successfully matched with metadata
    case matched(MovieMetadata)
    /// No match found on TMDb
    case notFound
    /// API key not configured
    case apiKeyMissing
    /// Error occurred during matching
    case error(MetadataError)
}

// MARK: - Metadata Service

/// Main protocol for the metadata orchestration service
@MainActor
protocol MetadataServicing: ObservableObject {
    /// Whether an API key is configured
    var isAPIKeyConfigured: Bool { get }

    /// Fetch or load metadata for a single file
    /// - Parameters:
    ///   - file: The library file
    ///   - forceRefresh: If true, fetch from TMDb even if cached
    /// - Returns: The match result
    func fetchMetadata(for file: LibraryFile, forceRefresh: Bool) async -> MetadataMatchResult

    /// Get cached metadata for a file (no network)
    /// - Parameter file: The library file
    /// - Returns: Cached metadata or nil
    func cachedMetadata(for file: LibraryFile) -> MovieMetadata?

    /// Batch fetch metadata for multiple files
    /// - Parameters:
    ///   - files: The library files
    ///   - progressHandler: Called with progress updates (current, total)
    func fetchMetadata(for files: [LibraryFile], progressHandler: ((Int, Int) -> Void)?) async

    /// Clear all cached metadata
    func clearCache() throws

    /// Configure the TMDb API key
    /// - Parameter key: The API key
    func configureAPIKey(_ key: String) throws

    /// Remove the TMDb API key
    func removeAPIKey() throws
}
