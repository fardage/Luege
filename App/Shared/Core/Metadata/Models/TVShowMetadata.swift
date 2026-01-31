import Foundation

/// Represents cached TV show (series) metadata
struct TVShowMetadata: Codable, Sendable, Identifiable, Equatable, Hashable {
    /// Unique identifier (generated for local tracking)
    let id: UUID

    /// TMDb series ID
    let tmdbId: Int

    /// Series title
    let name: String

    /// Original language title
    let originalName: String?

    /// Series overview/synopsis
    let overview: String?

    /// First air date
    let firstAirDate: Date?

    /// TMDb poster path (relative, e.g., "/abc123.jpg")
    let posterPath: String?

    /// TMDb backdrop path (relative, e.g., "/xyz789.jpg")
    let backdropPath: String?

    /// Average user rating (0-10)
    let voteAverage: Double?

    /// Total number of seasons
    let numberOfSeasons: Int

    /// Total number of episodes
    let numberOfEpisodes: Int

    /// Genre names
    let genres: [String]

    /// Series status (e.g., "Returning Series", "Ended", "Canceled")
    let status: String?

    /// When this metadata was fetched
    let fetchedAt: Date

    init(
        id: UUID = UUID(),
        tmdbId: Int,
        name: String,
        originalName: String? = nil,
        overview: String? = nil,
        firstAirDate: Date? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        voteAverage: Double? = nil,
        numberOfSeasons: Int = 0,
        numberOfEpisodes: Int = 0,
        genres: [String] = [],
        status: String? = nil,
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.tmdbId = tmdbId
        self.name = name
        self.originalName = originalName
        self.overview = overview
        self.firstAirDate = firstAirDate
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.voteAverage = voteAverage
        self.numberOfSeasons = numberOfSeasons
        self.numberOfEpisodes = numberOfEpisodes
        self.genres = genres
        self.status = status
        self.fetchedAt = fetchedAt
    }

    /// Create metadata from TMDb series details
    static func from(details: TMDbTVSeriesDetails) -> TVShowMetadata {
        TVShowMetadata(
            tmdbId: details.id,
            name: details.name,
            originalName: details.originalName,
            overview: details.overview,
            firstAirDate: details.parsedFirstAirDate,
            posterPath: details.posterPath,
            backdropPath: details.backdropPath,
            voteAverage: details.voteAverage,
            numberOfSeasons: details.numberOfSeasons,
            numberOfEpisodes: details.numberOfEpisodes,
            genres: details.genreNames,
            status: details.status
        )
    }

    /// First air year
    var firstAirYear: Int? {
        guard let date = firstAirDate else { return nil }
        return Calendar.current.component(.year, from: date)
    }

    /// Formatted genres string (e.g., "Drama, Comedy")
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

    /// User-friendly status text
    var statusText: String? {
        guard let status = status else { return nil }
        switch status {
        case "Returning Series":
            return "Continuing"
        case "Ended":
            return "Ended"
        case "Canceled":
            return "Canceled"
        case "In Production":
            return "In Production"
        default:
            return status
        }
    }
}
