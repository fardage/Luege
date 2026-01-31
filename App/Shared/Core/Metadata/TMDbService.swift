import Foundation

/// Service for interacting with the TMDb API
final class TMDbService: MetadataFetching, @unchecked Sendable {
    private let apiKeyStore: APIKeyStoring
    private let session: URLSession
    private let baseURL = "https://api.themoviedb.org/3"

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    init(apiKeyStore: APIKeyStoring, session: URLSession = .shared) {
        self.apiKeyStore = apiKeyStore
        self.session = session
    }

    // MARK: - MetadataFetching

    func searchMovies(title: String, year: Int?) async throws -> [TMDbSearchResult] {
        let apiKey = try getAPIKey()

        var components = URLComponents(string: "\(baseURL)/search/movie")!
        var queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: title),
            URLQueryItem(name: "include_adult", value: "false")
        ]

        if let year = year {
            queryItems.append(URLQueryItem(name: "year", value: String(year)))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw MetadataError.networkError("Invalid URL")
        }

        let response: TMDbSearchResponse = try await performRequest(url: url)
        return response.results
    }

    func fetchMovieDetails(tmdbId: Int) async throws -> TMDbMovieDetails {
        let apiKey = try getAPIKey()

        var components = URLComponents(string: "\(baseURL)/movie/\(tmdbId)")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        guard let url = components.url else {
            throw MetadataError.networkError("Invalid URL")
        }

        return try await performRequest(url: url)
    }

    // MARK: - Private

    private func getAPIKey() throws -> String {
        guard let apiKey = try apiKeyStore.retrieveAPIKey() else {
            throw MetadataError.apiKeyNotConfigured
        }
        return apiKey
    }

    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        let request = URLRequest(url: url)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MetadataError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MetadataError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw MetadataError.invalidAPIKey
        case 429:
            throw MetadataError.rateLimited
        case 404:
            throw MetadataError.movieNotFound
        default:
            // Try to parse error response
            if let errorResponse = try? decoder.decode(TMDbErrorResponse.self, from: data) {
                throw MetadataError.apiError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.statusMessage
                )
            }
            throw MetadataError.apiError(
                statusCode: httpResponse.statusCode,
                message: "Unknown error"
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MetadataError.parsingFailed(error.localizedDescription)
        }
    }
}

// MARK: - TMDb Image URLs

extension TMDbService {
    /// Base URL for TMDb images
    static let imageBaseURL = "https://image.tmdb.org/t/p"

    /// Generate a poster image URL
    /// - Parameters:
    ///   - path: The poster path from TMDb
    ///   - size: The desired size
    /// - Returns: Full URL for the poster image
    static func posterURL(path: String, size: PosterSize = .w342) -> URL? {
        URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
    }

    /// Generate a backdrop image URL
    /// - Parameters:
    ///   - path: The backdrop path from TMDb
    ///   - size: The desired size
    /// - Returns: Full URL for the backdrop image
    static func backdropURL(path: String, size: BackdropSize = .w780) -> URL? {
        URL(string: "\(imageBaseURL)/\(size.rawValue)\(path)")
    }

    /// Available poster sizes from TMDb
    enum PosterSize: String, Sendable {
        case w92
        case w154
        case w185
        case w342
        case w500
        case w780
        case original
    }

    /// Available backdrop sizes from TMDb
    enum BackdropSize: String, Sendable {
        case w300
        case w780
        case w1280
        case original
    }
}
