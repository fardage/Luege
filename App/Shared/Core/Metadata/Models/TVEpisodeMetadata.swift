import Foundation

/// Represents cached TV episode metadata
struct TVEpisodeMetadata: Codable, Sendable, Identifiable, Equatable, Hashable {
    /// The library file ID this metadata belongs to
    let id: UUID

    /// TMDb series ID this episode belongs to
    let seriesTmdbId: Int

    /// TMDb episode ID
    let tmdbEpisodeId: Int?

    /// Season number
    let seasonNumber: Int

    /// Episode number within the season
    let episodeNumber: Int

    /// Episode title
    let name: String

    /// Episode synopsis/overview
    let overview: String?

    /// TMDb still path (episode thumbnail, relative, e.g., "/abc123.jpg")
    let stillPath: String?

    /// Original air date
    let airDate: Date?

    /// Runtime in minutes
    let runtime: Int?

    /// Average user rating (0-10)
    let voteAverage: Double?

    /// How this metadata was matched
    var matchStatus: MatchStatus

    /// When this metadata was fetched
    let fetchedAt: Date

    /// Match status indicating how metadata was obtained
    enum MatchStatus: String, Codable, Sendable {
        /// Automatically matched from TMDb
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
        seriesTmdbId: Int,
        tmdbEpisodeId: Int? = nil,
        seasonNumber: Int,
        episodeNumber: Int,
        name: String,
        overview: String? = nil,
        stillPath: String? = nil,
        airDate: Date? = nil,
        runtime: Int? = nil,
        voteAverage: Double? = nil,
        matchStatus: MatchStatus = .matched,
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.seriesTmdbId = seriesTmdbId
        self.tmdbEpisodeId = tmdbEpisodeId
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.name = name
        self.overview = overview
        self.stillPath = stillPath
        self.airDate = airDate
        self.runtime = runtime
        self.voteAverage = voteAverage
        self.matchStatus = matchStatus
        self.fetchedAt = fetchedAt
    }

    /// Create metadata from TMDb episode
    static func from(
        episode: TMDbEpisode,
        fileId: UUID,
        seriesTmdbId: Int,
        matchStatus: MatchStatus = .matched
    ) -> TVEpisodeMetadata {
        TVEpisodeMetadata(
            id: fileId,
            seriesTmdbId: seriesTmdbId,
            tmdbEpisodeId: episode.id,
            seasonNumber: episode.seasonNumber,
            episodeNumber: episode.episodeNumber,
            name: episode.name,
            overview: episode.overview,
            stillPath: episode.stillPath,
            airDate: episode.parsedAirDate,
            runtime: episode.runtime,
            voteAverage: episode.voteAverage,
            matchStatus: matchStatus
        )
    }

    /// Create unmatched metadata from parse result
    static func unmatched(
        fileId: UUID,
        parseResult: TVShowParseResult
    ) -> TVEpisodeMetadata {
        TVEpisodeMetadata(
            id: fileId,
            seriesTmdbId: 0,
            seasonNumber: parseResult.season ?? 0,
            episodeNumber: parseResult.episode ?? 0,
            name: parseResult.showName,
            matchStatus: .unmatched
        )
    }

    /// Formatted episode number (e.g., "S01E03")
    var formattedEpisode: String {
        String(format: "S%02dE%02d", seasonNumber, episodeNumber)
    }

    /// Formatted runtime string (e.g., "45m")
    var formattedRuntime: String? {
        guard let runtime = runtime, runtime > 0 else { return nil }
        if runtime >= 60 {
            let hours = runtime / 60
            let minutes = runtime % 60
            return "\(hours)h \(minutes)m"
        }
        return "\(runtime)m"
    }

    /// Formatted air date (e.g., "Jan 15, 2024")
    var formattedAirDate: String? {
        guard let date = airDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Air year
    var airYear: Int? {
        guard let date = airDate else { return nil }
        return Calendar.current.component(.year, from: date)
    }

    /// Whether this metadata has a still image
    var hasStill: Bool {
        stillPath != nil
    }

    /// Whether this is matched metadata from TMDb
    var isMatched: Bool {
        matchStatus == .matched || matchStatus == .manuallyMatched
    }
}
