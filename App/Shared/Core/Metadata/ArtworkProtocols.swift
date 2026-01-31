import Foundation

/// Protocol for downloading artwork images
protocol ArtworkDownloading: Sendable {
    /// Download and cache a poster image
    func downloadAndCachePoster(tmdbPath: String, for fileId: UUID, size: PosterSize) async throws

    /// Download and cache a backdrop image
    func downloadAndCacheBackdrop(tmdbPath: String, for fileId: UUID, size: BackdropSize) async throws
}

/// Protocol for caching artwork images
protocol ArtworkCaching: Sendable {
    /// Cache a poster image for a file
    /// - Parameters:
    ///   - data: The image data
    ///   - fileId: The library file ID
    ///   - size: The poster size
    func cachePoster(_ data: Data, for fileId: UUID, size: PosterSize) throws

    /// Cache a backdrop image for a file
    /// - Parameters:
    ///   - data: The image data
    ///   - fileId: The library file ID
    ///   - size: The backdrop size
    func cacheBackdrop(_ data: Data, for fileId: UUID, size: BackdropSize) throws

    /// Get cached poster data
    /// - Parameters:
    ///   - fileId: The library file ID
    ///   - size: The poster size
    /// - Returns: Cached image data, or nil if not cached
    func getCachedPoster(for fileId: UUID, size: PosterSize) -> Data?

    /// Get cached backdrop data
    /// - Parameters:
    ///   - fileId: The library file ID
    ///   - size: The backdrop size
    /// - Returns: Cached image data, or nil if not cached
    func getCachedBackdrop(for fileId: UUID, size: BackdropSize) -> Data?

    /// Get the file URL for a cached poster
    /// - Parameters:
    ///   - fileId: The library file ID
    ///   - size: The poster size
    /// - Returns: File URL if cached, nil otherwise
    func posterURL(for fileId: UUID, size: PosterSize) -> URL?

    /// Get the file URL for a cached backdrop
    /// - Parameters:
    ///   - fileId: The library file ID
    ///   - size: The backdrop size
    /// - Returns: File URL if cached, nil otherwise
    func backdropURL(for fileId: UUID, size: BackdropSize) -> URL?

    /// Delete cached artwork for a file
    /// - Parameter fileId: The library file ID
    func deleteArtwork(for fileId: UUID) throws

    /// Delete all cached artwork
    func deleteAllArtwork() throws

    /// Get total cache size in bytes
    func cacheSize() throws -> Int64
}

// MARK: - Poster Sizes

/// Available poster sizes for caching
enum PosterSize: String, Sendable, CaseIterable {
    /// 92 pixels wide - for small thumbnails
    case w92
    /// 154 pixels wide - for small list items
    case w154
    /// 185 pixels wide - for medium thumbnails
    case w185
    /// 342 pixels wide - for grid cards (default)
    case w342
    /// 500 pixels wide - for detail views
    case w500
    /// 780 pixels wide - for large displays
    case w780
    /// Original resolution
    case original

    /// The default size for grid display
    static var grid: PosterSize { .w342 }

    /// The default size for detail view
    static var detail: PosterSize { .w500 }
}

// MARK: - Backdrop Sizes

/// Available backdrop sizes for caching
enum BackdropSize: String, Sendable, CaseIterable {
    /// 300 pixels wide - for small previews
    case w300
    /// 780 pixels wide - for medium displays (default)
    case w780
    /// 1280 pixels wide - for large displays
    case w1280
    /// Original resolution
    case original

    /// The default size for background display
    static var `default`: BackdropSize { .w780 }

    /// The size for tvOS full-screen display
    static var tvOS: BackdropSize { .w1280 }
}
