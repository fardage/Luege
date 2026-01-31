import Foundation

/// Represents cached TV season metadata
struct TVSeasonMetadata: Codable, Sendable, Identifiable, Equatable, Hashable {
    /// Unique identifier (generated for local tracking)
    let id: UUID

    /// TMDb series ID this season belongs to
    let seriesTmdbId: Int

    /// Season number (0 = specials)
    let seasonNumber: Int

    /// Season name (e.g., "Season 1" or custom name)
    let name: String?

    /// Season overview/synopsis
    let overview: String?

    /// TMDb poster path (relative, e.g., "/abc123.jpg")
    let posterPath: String?

    /// Air date of first episode
    let airDate: Date?

    /// Number of episodes in this season
    let episodeCount: Int

    /// When this metadata was fetched
    let fetchedAt: Date

    init(
        id: UUID = UUID(),
        seriesTmdbId: Int,
        seasonNumber: Int,
        name: String? = nil,
        overview: String? = nil,
        posterPath: String? = nil,
        airDate: Date? = nil,
        episodeCount: Int = 0,
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.seriesTmdbId = seriesTmdbId
        self.seasonNumber = seasonNumber
        self.name = name
        self.overview = overview
        self.posterPath = posterPath
        self.airDate = airDate
        self.episodeCount = episodeCount
        self.fetchedAt = fetchedAt
    }

    /// Create metadata from TMDb season summary
    static func from(summary: TMDbSeasonSummary, seriesTmdbId: Int) -> TVSeasonMetadata {
        TVSeasonMetadata(
            seriesTmdbId: seriesTmdbId,
            seasonNumber: summary.seasonNumber,
            name: summary.name,
            overview: summary.overview,
            posterPath: summary.posterPath,
            airDate: summary.parsedAirDate,
            episodeCount: summary.episodeCount
        )
    }

    /// Create metadata from TMDb season details
    static func from(details: TMDbSeasonDetails, seriesTmdbId: Int) -> TVSeasonMetadata {
        TVSeasonMetadata(
            seriesTmdbId: seriesTmdbId,
            seasonNumber: details.seasonNumber,
            name: details.name,
            overview: details.overview,
            posterPath: details.posterPath,
            airDate: details.parsedAirDate,
            episodeCount: details.episodes?.count ?? 0
        )
    }

    /// Display name for the season
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        if seasonNumber == 0 {
            return "Specials"
        }
        return "Season \(seasonNumber)"
    }

    /// Air year
    var airYear: Int? {
        guard let date = airDate else { return nil }
        return Calendar.current.component(.year, from: date)
    }

    /// Whether this metadata has a poster
    var hasPoster: Bool {
        posterPath != nil
    }

    /// Whether this is the specials season
    var isSpecials: Bool {
        seasonNumber == 0
    }
}
