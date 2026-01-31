import XCTest
@testable import Luege

@MainActor
final class MetadataServiceTests: XCTestCase {
    var mockFetcher: MockMetadataFetcher!
    var mockStorage: MockMetadataStorage!
    var mockArtworkCache: MockArtworkCache!
    var mockAPIKeyStorage: MockAPIKeyStorage!
    var service: MetadataService!

    override func setUp() async throws {
        try await super.setUp()
        mockFetcher = MockMetadataFetcher()
        mockStorage = MockMetadataStorage()
        mockArtworkCache = MockArtworkCache()
        mockAPIKeyStorage = MockAPIKeyStorage(apiKey: "test-api-key")

        service = MetadataService(
            fetcher: mockFetcher,
            storage: mockStorage,
            artworkCache: mockArtworkCache,
            artworkDownloader: nil,
            apiKeyStorage: mockAPIKeyStorage
        )
    }

    override func tearDown() async throws {
        mockFetcher = nil
        mockStorage = nil
        mockArtworkCache = nil
        mockAPIKeyStorage = nil
        service = nil
        try await super.tearDown()
    }

    // MARK: - API Key Tests

    func testIsAPIKeyConfiguredReflectsStorage() async {
        XCTAssertTrue(service.isAPIKeyConfigured)

        let noKeyService = MetadataService(
            fetcher: mockFetcher,
            storage: mockStorage,
            artworkCache: mockArtworkCache,
            artworkDownloader: nil,
            apiKeyStorage: MockAPIKeyStorage(apiKey: nil)
        )
        XCTAssertFalse(noKeyService.isAPIKeyConfigured)
    }

    func testConfigureAPIKey() throws {
        let noKeyStorage = MockAPIKeyStorage(apiKey: nil)
        let noKeyService = MetadataService(
            fetcher: mockFetcher,
            storage: mockStorage,
            artworkCache: mockArtworkCache,
            artworkDownloader: nil,
            apiKeyStorage: noKeyStorage
        )

        try noKeyService.configureAPIKey("new-api-key")

        XCTAssertTrue(noKeyService.isAPIKeyConfigured)
        XCTAssertEqual(noKeyStorage.storeCallCount, 1)
    }

    func testRemoveAPIKey() throws {
        try service.removeAPIKey()

        XCTAssertFalse(service.isAPIKeyConfigured)
        XCTAssertEqual(mockAPIKeyStorage.deleteCallCount, 1)
    }

    // MARK: - Fetch Metadata Tests

    func testFetchMetadataReturnsMatchedFromCache() async {
        let fileId = UUID()
        let file = makeLibraryFile(id: fileId, fileName: "The Matrix (1999).mkv")
        let metadata = makeMetadata(id: fileId, title: "The Matrix")
        mockStorage.setMetadata(metadata, for: fileId)

        // Allow cache to load
        try? await Task.sleep(nanoseconds: 100_000_000)

        let result = await service.fetchMetadata(for: file)

        if case .matched(let matched) = result {
            XCTAssertEqual(matched.title, "The Matrix")
        } else {
            XCTFail("Expected matched result")
        }
        XCTAssertEqual(mockFetcher.searchCallCount, 0) // Should not call API
    }

    func testFetchMetadataFromTMDb() async {
        let fileId = UUID()
        let file = makeLibraryFile(id: fileId, fileName: "The Matrix (1999).mkv")

        mockFetcher.searchResults = [.mock(id: 603, title: "The Matrix", releaseDate: "1999-03-30")]
        mockFetcher.movieDetails = .mock(id: 603, title: "The Matrix", runtime: 136)

        let result = await service.fetchMetadata(for: file)

        if case .matched(let metadata) = result {
            XCTAssertEqual(metadata.tmdbId, 603)
            XCTAssertEqual(metadata.title, "The Matrix")
            XCTAssertEqual(metadata.runtime, 136)
        } else {
            XCTFail("Expected matched result, got: \(result)")
        }

        XCTAssertEqual(mockFetcher.searchCallCount, 1)
        XCTAssertEqual(mockFetcher.detailsCallCount, 1)
        XCTAssertEqual(mockStorage.saveCallCount, 1)
    }

    func testFetchMetadataNoMatchReturnsNotFound() async {
        let fileId = UUID()
        let file = makeLibraryFile(id: fileId, fileName: "Unknown Movie.mkv")

        mockFetcher.searchResults = []

        let result = await service.fetchMetadata(for: file)

        if case .notFound = result {
            // Expected
        } else {
            XCTFail("Expected notFound result")
        }

        // Should still save as unmatched
        XCTAssertEqual(mockStorage.saveCallCount, 1)
    }

    func testFetchMetadataWithoutAPIKeyReturnsApiKeyMissing() async {
        let noKeyService = MetadataService(
            fetcher: mockFetcher,
            storage: mockStorage,
            artworkCache: mockArtworkCache,
            artworkDownloader: nil,
            apiKeyStorage: MockAPIKeyStorage(apiKey: nil)
        )

        let file = makeLibraryFile(id: UUID(), fileName: "Test.mkv")
        let result = await noKeyService.fetchMetadata(for: file)

        if case .apiKeyMissing = result {
            // Expected
        } else {
            XCTFail("Expected apiKeyMissing result")
        }
    }

    func testFetchMetadataReturnsErrorOnNetworkFailure() async {
        let file = makeLibraryFile(id: UUID(), fileName: "Test.mkv")
        mockFetcher.searchError = .networkError("Connection failed")

        let result = await service.fetchMetadata(for: file)

        if case .error(let error) = result {
            XCTAssertEqual(error, .networkError("Connection failed"))
        } else {
            XCTFail("Expected error result")
        }
    }

    func testForceRefreshBypassesCache() async {
        let fileId = UUID()
        let file = makeLibraryFile(id: fileId, fileName: "The Matrix (1999).mkv")
        let cachedMetadata = makeMetadata(id: fileId, title: "Cached Title")
        mockStorage.setMetadata(cachedMetadata, for: fileId)

        mockFetcher.searchResults = [.mock(id: 603, title: "Fresh Title")]
        mockFetcher.movieDetails = .mock(id: 603, title: "Fresh Title")

        // Allow cache to load
        try? await Task.sleep(nanoseconds: 100_000_000)

        let result = await service.fetchMetadata(for: file, forceRefresh: true)

        if case .matched(let metadata) = result {
            XCTAssertEqual(metadata.title, "Fresh Title")
        } else {
            XCTFail("Expected matched result")
        }

        XCTAssertEqual(mockFetcher.searchCallCount, 1)
    }

    // MARK: - Year Matching Tests

    func testSelectsBestMatchByYear() async {
        let file = makeLibraryFile(id: UUID(), fileName: "Inception (2010).mkv")

        mockFetcher.searchResults = [
            .mock(id: 1, title: "Inception Documentary", releaseDate: "2015-01-01"),
            .mock(id: 2, title: "Inception", releaseDate: "2010-07-16"),
            .mock(id: 3, title: "Another Inception", releaseDate: "2008-03-15")
        ]
        mockFetcher.movieDetails = .mock(id: 2, title: "Inception")

        let result = await service.fetchMetadata(for: file)

        if case .matched = result {
            XCTAssertEqual(mockFetcher.lastDetailsTmdbId, 2) // Should pick 2010 match
        } else {
            XCTFail("Expected matched result")
        }
    }

    // MARK: - Cache Management Tests

    func testCachedMetadataReturnsFromMemory() async {
        let fileId = UUID()
        let file = makeLibraryFile(id: fileId, fileName: "Test.mkv")
        let metadata = makeMetadata(id: fileId, title: "Cached")
        mockStorage.setMetadata(metadata, for: fileId)

        // Allow cache to load
        try? await Task.sleep(nanoseconds: 100_000_000)

        let cached = service.cachedMetadata(for: file)
        XCTAssertEqual(cached?.title, "Cached")
    }

    func testCachedMetadataReturnsNilWhenNotCached() {
        let file = makeLibraryFile(id: UUID(), fileName: "Unknown.mkv")
        let cached = service.cachedMetadata(for: file)
        XCTAssertNil(cached)
    }

    func testClearCache() throws {
        let fileId = UUID()
        mockStorage.setMetadata(makeMetadata(id: fileId, title: "Test"), for: fileId)

        try service.clearCache()

        XCTAssertFalse(mockStorage.exists(for: fileId))
    }

    // MARK: - Helper Methods

    private func makeLibraryFile(
        id: UUID = UUID(),
        fileName: String = "test.mkv"
    ) -> LibraryFile {
        LibraryFile(
            id: id,
            folderId: UUID(),
            relativePath: fileName,
            fileName: fileName,
            size: 1000,
            modifiedDate: nil
        )
    }

    private func makeMetadata(
        id: UUID,
        title: String = "Test Movie"
    ) -> MovieMetadata {
        MovieMetadata(
            id: id,
            tmdbId: 123,
            title: title,
            year: 2020,
            matchStatus: .matched
        )
    }
}
