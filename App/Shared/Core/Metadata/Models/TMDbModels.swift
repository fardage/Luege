import Foundation

// MARK: - Search Response

/// TMDb movie search response
struct TMDbSearchResponse: Codable, Sendable {
    let page: Int
    let results: [TMDbSearchResult]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

/// A single search result from TMDb
struct TMDbSearchResult: Codable, Sendable, Identifiable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let adult: Bool?
    let genreIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case originalTitle = "original_title"
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case popularity
        case adult
        case genreIds = "genre_ids"
    }

    /// Parse release date string to year
    var releaseYear: Int? {
        guard let releaseDate = releaseDate, releaseDate.count >= 4 else { return nil }
        return Int(String(releaseDate.prefix(4)))
    }
}

// MARK: - Movie Details

/// Detailed movie information from TMDb
struct TMDbMovieDetails: Codable, Sendable {
    let id: Int
    let title: String
    let originalTitle: String?
    let overview: String?
    let releaseDate: String?
    let runtime: Int?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let genres: [TMDbGenre]?
    let productionCompanies: [TMDbProductionCompany]?
    let productionCountries: [TMDbProductionCountry]?
    let status: String?
    let tagline: String?
    let budget: Int?
    let revenue: Int?
    let imdbId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case originalTitle = "original_title"
        case overview
        case releaseDate = "release_date"
        case runtime
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genres
        case productionCompanies = "production_companies"
        case productionCountries = "production_countries"
        case status
        case tagline
        case budget
        case revenue
        case imdbId = "imdb_id"
    }

    /// Parse release date string to Date
    var parsedReleaseDate: Date? {
        guard let releaseDate = releaseDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: releaseDate)
    }

    /// Parse release date string to year
    var releaseYear: Int? {
        guard let releaseDate = releaseDate, releaseDate.count >= 4 else { return nil }
        return Int(String(releaseDate.prefix(4)))
    }

    /// Genre names as an array of strings
    var genreNames: [String] {
        genres?.map(\.name) ?? []
    }
}

/// TMDb genre
struct TMDbGenre: Codable, Sendable, Identifiable {
    let id: Int
    let name: String
}

/// TMDb production company
struct TMDbProductionCompany: Codable, Sendable, Identifiable {
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

/// TMDb production country
struct TMDbProductionCountry: Codable, Sendable {
    let iso31661: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case name
    }
}

// MARK: - Error Response

/// TMDb API error response
struct TMDbErrorResponse: Codable, Sendable {
    let statusCode: Int
    let statusMessage: String
    let success: Bool

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMessage = "status_message"
        case success
    }
}

// MARK: - Configuration

/// TMDb API configuration response
struct TMDbConfiguration: Codable, Sendable {
    let images: TMDbImagesConfiguration

    struct TMDbImagesConfiguration: Codable, Sendable {
        let baseUrl: String
        let secureBaseUrl: String
        let posterSizes: [String]
        let backdropSizes: [String]
        let profileSizes: [String]
        let stillSizes: [String]
        let logoSizes: [String]

        enum CodingKeys: String, CodingKey {
            case baseUrl = "base_url"
            case secureBaseUrl = "secure_base_url"
            case posterSizes = "poster_sizes"
            case backdropSizes = "backdrop_sizes"
            case profileSizes = "profile_sizes"
            case stillSizes = "still_sizes"
            case logoSizes = "logo_sizes"
        }
    }
}
