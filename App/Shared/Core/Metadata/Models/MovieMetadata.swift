import Foundation

/// Represents cached movie metadata for a library file
struct MovieMetadata: Codable, Sendable, Identifiable, Equatable {
    /// The library file ID this metadata belongs to
    let id: UUID

    /// TMDb movie ID (nil if not matched)
    let tmdbId: Int?

    /// Display title
    let title: String

    /// Original language title
    let originalTitle: String?

    /// Release year
    let year: Int?

    /// Full release date
    let releaseDate: Date?

    /// Runtime in minutes
    let runtime: Int?

    /// Genre names
    let genres: [String]

    /// Movie synopsis/overview
    let synopsis: String?

    /// TMDb poster path (relative, e.g., "/abc123.jpg")
    let posterPath: String?

    /// TMDb backdrop path (relative, e.g., "/xyz789.jpg")
    let backdropPath: String?

    /// Average user rating (0-10)
    let voteAverage: Double?

    /// How this metadata was matched
    var matchStatus: MatchStatus

    /// When this metadata was fetched
    let fetchedAt: Date

    /// Match status indicating how metadata was obtained
    enum MatchStatus: String, Codable, Sendable {
        /// Automatically matched from TMDb search
        case matched
        /// No match found on TMDb
        case unmatched
        /// User manually selected a match
        case manuallyMatched
        /// User explicitly skipped matching
        case manuallySkipped
    }

    init(
        id: UUID,
        tmdbId: Int? = nil,
        title: String,
        originalTitle: String? = nil,
        year: Int? = nil,
        releaseDate: Date? = nil,
        runtime: Int? = nil,
        genres: [String] = [],
        synopsis: String? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        voteAverage: Double? = nil,
        matchStatus: MatchStatus = .matched,
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.tmdbId = tmdbId
        self.title = title
        self.originalTitle = originalTitle
        self.year = year
        self.releaseDate = releaseDate
        self.runtime = runtime
        self.genres = genres
        self.synopsis = synopsis
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.voteAverage = voteAverage
        self.matchStatus = matchStatus
        self.fetchedAt = fetchedAt
    }

    /// Create metadata from TMDb movie details
    static func from(
        details: TMDbMovieDetails,
        fileId: UUID,
        matchStatus: MatchStatus = .matched
    ) -> MovieMetadata {
        MovieMetadata(
            id: fileId,
            tmdbId: details.id,
            title: details.title,
            originalTitle: details.originalTitle,
            year: details.releaseYear,
            releaseDate: details.parsedReleaseDate,
            runtime: details.runtime,
            genres: details.genreNames,
            synopsis: details.overview,
            posterPath: details.posterPath,
            backdropPath: details.backdropPath,
            voteAverage: details.voteAverage,
            matchStatus: matchStatus
        )
    }

    /// Create unmatched metadata using filename info
    static func unmatched(
        fileId: UUID,
        parseResult: FilenameParseResult
    ) -> MovieMetadata {
        MovieMetadata(
            id: fileId,
            tmdbId: nil,
            title: parseResult.title,
            year: parseResult.year,
            matchStatus: .unmatched
        )
    }

    /// Formatted runtime string (e.g., "2h 15m")
    var formattedRuntime: String? {
        guard let runtime = runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Formatted genres string (e.g., "Action, Sci-Fi")
    var formattedGenres: String? {
        guard !genres.isEmpty else { return nil }
        return genres.joined(separator: ", ")
    }

    /// Whether this metadata has a poster
    var hasPoster: Bool {
        posterPath != nil
    }

    /// Whether this metadata has a backdrop
    var hasBackdrop: Bool {
        backdropPath != nil
    }

    /// Whether this is matched metadata from TMDb
    var isMatched: Bool {
        matchStatus == .matched || matchStatus == .manuallyMatched
    }
}
