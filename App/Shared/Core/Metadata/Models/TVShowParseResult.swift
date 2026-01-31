import Foundation

/// Result of parsing TV show information from a filename
struct TVShowParseResult: Sendable, Equatable {
    /// The extracted show name
    let showName: String

    /// The season number if found
    let season: Int?

    /// The episode number if found
    let episode: Int?

    /// The ending episode number for multi-episode files (e.g., S01E03-E04)
    let episodeEnd: Int?

    /// Quality indicator if found (e.g., "1080p", "4K", "720p")
    let quality: String?

    init(
        showName: String,
        season: Int? = nil,
        episode: Int? = nil,
        episodeEnd: Int? = nil,
        quality: String? = nil
    ) {
        self.showName = showName
        self.season = season
        self.episode = episode
        self.episodeEnd = episodeEnd
        self.quality = quality
    }

    /// Whether this is a valid TV show parse (has season and episode)
    var isValid: Bool {
        season != nil && episode != nil
    }

    /// Whether this represents a multi-episode file
    var isMultiEpisode: Bool {
        episodeEnd != nil && episodeEnd != episode
    }

    /// Format season/episode as "S01E03" or "S01E03-E04" for multi-episode
    var formattedEpisode: String? {
        guard let season = season, let episode = episode else { return nil }
        let base = String(format: "S%02dE%02d", season, episode)
        if let end = episodeEnd, end != episode {
            return "\(base)-E\(String(format: "%02d", end))"
        }
        return base
    }
}
