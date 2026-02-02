import Foundation

// MARK: - TV Search Response

/// TMDb TV show search response
struct TMDbTVSearchResponse: Codable, Sendable {
    let page: Int
    let results: [TMDbTVSearchResult]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

/// A single TV show search result from TMDb
struct TMDbTVSearchResult: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
    let originalName: String?
    let overview: String?
    let firstAirDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let genreIds: [Int]?
    let originCountry: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case originalName = "original_name"
        case overview
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case popularity
        case genreIds = "genre_ids"
        case originCountry = "origin_country"
    }

    /// Parse first air date string to year
    var firstAirYear: Int? {
        guard let firstAirDate = firstAirDate, firstAirDate.count >= 4 else { return nil }
        return Int(String(firstAirDate.prefix(4)))
    }
}

// MARK: - TV Series Details

/// Detailed TV series information from TMDb
struct TMDbTVSeriesDetails: Codable, Sendable {
    let id: Int
    let name: String
    let originalName: String?
    let overview: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let numberOfSeasons: Int
    let numberOfEpisodes: Int
    let genres: [TMDbGenre]?
    let status: String?
    let tagline: String?
    let type: String?
    let networks: [TMDbNetwork]?
    let seasons: [TMDbSeasonSummary]?
    let createdBy: [TMDbCreator]?
    let inProduction: Bool?
    let homepage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case originalName = "original_name"
        case overview
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case genres
        case status
        case tagline
        case type
        case networks
        case seasons
        case createdBy = "created_by"
        case inProduction = "in_production"
        case homepage
    }

    /// Parse first air date string to Date
    var parsedFirstAirDate: Date? {
        guard let firstAirDate = firstAirDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: firstAirDate)
    }

    /// Parse first air date string to year
    var firstAirYear: Int? {
        guard let firstAirDate = firstAirDate, firstAirDate.count >= 4 else { return nil }
        return Int(String(firstAirDate.prefix(4)))
    }

    /// Genre names as an array of strings
    var genreNames: [String] {
        genres?.map(\.name) ?? []
    }
}

/// TMDb network information
struct TMDbNetwork: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String?
    let originCountry: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case logoPath = "logo_path"
        case originCountry = "origin_country"
    }
}

/// TMDb creator information
struct TMDbCreator: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
    let profilePath: String?
    let creditId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case profilePath = "profile_path"
        case creditId = "credit_id"
    }
}

// MARK: - Season Information

/// Season summary included in series details
struct TMDbSeasonSummary: Codable, Sendable, Identifiable {
    var id: Int { seasonNumber }
    let seasonNumber: Int
    let name: String?
    let overview: String?
    let episodeCount: Int
    let posterPath: String?
    let airDate: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case name
        case overview
        case episodeCount = "episode_count"
        case posterPath = "poster_path"
        case airDate = "air_date"
        case voteAverage = "vote_average"
    }

    /// Parse air date string to Date
    var parsedAirDate: Date? {
        guard let airDate = airDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: airDate)
    }

    /// Parse air date string to year
    var airYear: Int? {
        guard let airDate = airDate, airDate.count >= 4 else { return nil }
        return Int(String(airDate.prefix(4)))
    }
}

/// Detailed season information from TMDb
struct TMDbSeasonDetails: Codable, Sendable {
    let id: Int
    let seasonNumber: Int
    let name: String?
    let overview: String?
    let posterPath: String?
    let airDate: String?
    let episodes: [TMDbEpisode]?

    enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber = "season_number"
        case name
        case overview
        case posterPath = "poster_path"
        case airDate = "air_date"
        case episodes
    }

    /// Parse air date string to Date
    var parsedAirDate: Date? {
        guard let airDate = airDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: airDate)
    }
}

// MARK: - Episode Information

/// Episode information from TMDb
struct TMDbEpisode: Codable, Sendable, Identifiable {
    let id: Int
    let episodeNumber: Int
    let seasonNumber: Int
    let name: String
    let overview: String?
    let stillPath: String?
    let airDate: String?
    let runtime: Int?
    let voteAverage: Double?
    let voteCount: Int?
    let productionCode: String?
    let crew: [TMDbCrewMember]?
    let guestStars: [TMDbCastMember]?

    enum CodingKeys: String, CodingKey {
        case id
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case name
        case overview
        case stillPath = "still_path"
        case airDate = "air_date"
        case runtime
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case productionCode = "production_code"
        case crew
        case guestStars = "guest_stars"
    }

    /// Parse air date string to Date
    var parsedAirDate: Date? {
        guard let airDate = airDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: airDate)
    }

    /// Format season and episode as "S01E03"
    var formattedEpisode: String {
        String(format: "S%02dE%02d", seasonNumber, episodeNumber)
    }
}

/// TMDb crew member
struct TMDbCrewMember: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?
    let creditId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case job
        case department
        case profilePath = "profile_path"
        case creditId = "credit_id"
    }
}

/// TMDb cast member
struct TMDbCastMember: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let creditId: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case profilePath = "profile_path"
        case creditId = "credit_id"
        case order
    }
}
