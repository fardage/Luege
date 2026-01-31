import Foundation
@testable import Luege

/// Mock implementation of MetadataFetching for testing
final class MockMetadataFetcher: MetadataFetching, @unchecked Sendable {
    var searchResults: [TMDbSearchResult] = []
    var movieDetails: TMDbMovieDetails?
    var searchError: MetadataError?
    var detailsError: MetadataError?

    var searchCallCount = 0
    var detailsCallCount = 0
    var lastSearchTitle: String?
    var lastSearchYear: Int?
    var lastDetailsTmdbId: Int?

    func searchMovies(title: String, year: Int?) async throws -> [TMDbSearchResult] {
        searchCallCount += 1
        lastSearchTitle = title
        lastSearchYear = year

        if let error = searchError {
            throw error
        }

        return searchResults
    }

    func fetchMovieDetails(tmdbId: Int) async throws -> TMDbMovieDetails {
        detailsCallCount += 1
        lastDetailsTmdbId = tmdbId

        if let error = detailsError {
            throw error
        }

        guard let details = movieDetails else {
            throw MetadataError.movieNotFound
        }

        return details
    }
}

// MARK: - Test Data Helpers

extension TMDbSearchResult {
    static func mock(
        id: Int = 603,
        title: String = "The Matrix",
        releaseDate: String? = "1999-03-30",
        posterPath: String? = "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
        voteAverage: Double? = 8.2
    ) -> TMDbSearchResult {
        TMDbSearchResult(
            id: id,
            title: title,
            originalTitle: title,
            overview: "A test movie",
            releaseDate: releaseDate,
            posterPath: posterPath,
            backdropPath: "/fNG7i7RqMErkcqhohV2a6cV1Ehy.jpg",
            voteAverage: voteAverage,
            voteCount: 1000,
            popularity: 50.0,
            adult: false,
            genreIds: [28, 878]
        )
    }
}

extension TMDbMovieDetails {
    static func mock(
        id: Int = 603,
        title: String = "The Matrix",
        releaseDate: String? = "1999-03-30",
        runtime: Int? = 136,
        genres: [TMDbGenre]? = [TMDbGenre(id: 28, name: "Action"), TMDbGenre(id: 878, name: "Science Fiction")],
        posterPath: String? = "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg"
    ) -> TMDbMovieDetails {
        TMDbMovieDetails(
            id: id,
            title: title,
            originalTitle: title,
            overview: "A computer hacker learns about the true nature of reality.",
            releaseDate: releaseDate,
            runtime: runtime,
            posterPath: posterPath,
            backdropPath: "/fNG7i7RqMErkcqhohV2a6cV1Ehy.jpg",
            voteAverage: 8.2,
            voteCount: 20000,
            genres: genres,
            productionCompanies: nil,
            productionCountries: nil,
            status: "Released",
            tagline: "Welcome to the Real World.",
            budget: 63000000,
            revenue: 466363891,
            imdbId: "tt0133093"
        )
    }
}
