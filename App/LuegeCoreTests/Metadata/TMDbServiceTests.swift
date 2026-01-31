import XCTest
@testable import Luege

final class TMDbServiceTests: XCTestCase {
    var apiKeyStorage: MockAPIKeyStorage!
    var service: TMDbService!

    override func setUp() {
        super.setUp()
        apiKeyStorage = MockAPIKeyStorage(apiKey: "test-api-key")
        service = TMDbService(apiKeyStore: apiKeyStorage)
    }

    override func tearDown() {
        apiKeyStorage = nil
        service = nil
        super.tearDown()
    }

    // MARK: - API Key Tests

    func testSearchWithoutAPIKeyThrows() async {
        apiKeyStorage = MockAPIKeyStorage(apiKey: nil)
        service = TMDbService(apiKeyStore: apiKeyStorage)

        do {
            _ = try await service.searchMovies(title: "Matrix", year: nil)
            XCTFail("Expected error to be thrown")
        } catch let error as MetadataError {
            XCTAssertEqual(error, MetadataError.apiKeyNotConfigured)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchDetailsWithoutAPIKeyThrows() async {
        apiKeyStorage = MockAPIKeyStorage(apiKey: nil)
        service = TMDbService(apiKeyStore: apiKeyStorage)

        do {
            _ = try await service.fetchMovieDetails(tmdbId: 603)
            XCTFail("Expected error to be thrown")
        } catch let error as MetadataError {
            XCTAssertEqual(error, MetadataError.apiKeyNotConfigured)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Image URL Tests

    func testPosterURLGeneration() {
        let path = "/abc123.jpg"
        let url = TMDbService.posterURL(path: path, size: .w342)

        XCTAssertEqual(url?.absoluteString, "https://image.tmdb.org/t/p/w342/abc123.jpg")
    }

    func testPosterURLWithDifferentSizes() {
        let path = "/abc123.jpg"

        XCTAssertEqual(
            TMDbService.posterURL(path: path, size: .w92)?.absoluteString,
            "https://image.tmdb.org/t/p/w92/abc123.jpg"
        )
        XCTAssertEqual(
            TMDbService.posterURL(path: path, size: .w500)?.absoluteString,
            "https://image.tmdb.org/t/p/w500/abc123.jpg"
        )
        XCTAssertEqual(
            TMDbService.posterURL(path: path, size: .original)?.absoluteString,
            "https://image.tmdb.org/t/p/original/abc123.jpg"
        )
    }

    func testBackdropURLGeneration() {
        let path = "/xyz789.jpg"
        let url = TMDbService.backdropURL(path: path, size: .w780)

        XCTAssertEqual(url?.absoluteString, "https://image.tmdb.org/t/p/w780/xyz789.jpg")
    }

    func testBackdropURLWithDifferentSizes() {
        let path = "/xyz789.jpg"

        XCTAssertEqual(
            TMDbService.backdropURL(path: path, size: .w300)?.absoluteString,
            "https://image.tmdb.org/t/p/w300/xyz789.jpg"
        )
        XCTAssertEqual(
            TMDbService.backdropURL(path: path, size: .w1280)?.absoluteString,
            "https://image.tmdb.org/t/p/w1280/xyz789.jpg"
        )
        XCTAssertEqual(
            TMDbService.backdropURL(path: path, size: .original)?.absoluteString,
            "https://image.tmdb.org/t/p/original/xyz789.jpg"
        )
    }
}

// MARK: - Mock Metadata Fetcher Tests

final class MockMetadataFetcherTests: XCTestCase {
    func testSearchReturnsConfiguredResults() async throws {
        let fetcher = MockMetadataFetcher()
        fetcher.searchResults = [
            .mock(id: 1, title: "Movie 1"),
            .mock(id: 2, title: "Movie 2")
        ]

        let results = try await fetcher.searchMovies(title: "Movie", year: nil)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "Movie 1")
        XCTAssertEqual(results[1].title, "Movie 2")
        XCTAssertEqual(fetcher.lastSearchTitle, "Movie")
    }

    func testSearchWithYearRecordsParameters() async throws {
        let fetcher = MockMetadataFetcher()
        fetcher.searchResults = [.mock()]

        _ = try await fetcher.searchMovies(title: "Matrix", year: 1999)

        XCTAssertEqual(fetcher.lastSearchTitle, "Matrix")
        XCTAssertEqual(fetcher.lastSearchYear, 1999)
        XCTAssertEqual(fetcher.searchCallCount, 1)
    }

    func testSearchThrowsConfiguredError() async {
        let fetcher = MockMetadataFetcher()
        fetcher.searchError = .rateLimited

        do {
            _ = try await fetcher.searchMovies(title: "Matrix", year: nil)
            XCTFail("Expected error")
        } catch let error as MetadataError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchDetailsReturnsConfiguredDetails() async throws {
        let fetcher = MockMetadataFetcher()
        fetcher.movieDetails = .mock(id: 603, title: "The Matrix", runtime: 136)

        let details = try await fetcher.fetchMovieDetails(tmdbId: 603)

        XCTAssertEqual(details.id, 603)
        XCTAssertEqual(details.title, "The Matrix")
        XCTAssertEqual(details.runtime, 136)
        XCTAssertEqual(fetcher.lastDetailsTmdbId, 603)
    }

    func testFetchDetailsWithoutConfigurationThrowsNotFound() async {
        let fetcher = MockMetadataFetcher()

        do {
            _ = try await fetcher.fetchMovieDetails(tmdbId: 999)
            XCTFail("Expected error")
        } catch let error as MetadataError {
            XCTAssertEqual(error, .movieNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
