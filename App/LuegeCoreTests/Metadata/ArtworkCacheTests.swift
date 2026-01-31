import XCTest
@testable import Luege

final class ArtworkCacheTests: XCTestCase {
    var cache: ArtworkCache!
    var testFileId: UUID!

    override func setUp() {
        super.setUp()
        cache = ArtworkCache()
        testFileId = UUID()
    }

    override func tearDown() {
        try? cache.deleteAllArtwork()
        cache = nil
        testFileId = nil
        super.tearDown()
    }

    // MARK: - Poster Caching

    func testCacheAndRetrievePoster() throws {
        let testData = "test poster data".data(using: .utf8)!

        try cache.cachePoster(testData, for: testFileId, size: .w342)
        let retrieved = cache.getCachedPoster(for: testFileId, size: .w342)

        XCTAssertEqual(retrieved, testData)
    }

    func testCacheMultiplePosterSizes() throws {
        let smallData = "small".data(using: .utf8)!
        let largeData = "large".data(using: .utf8)!

        try cache.cachePoster(smallData, for: testFileId, size: .w185)
        try cache.cachePoster(largeData, for: testFileId, size: .w500)

        XCTAssertEqual(cache.getCachedPoster(for: testFileId, size: .w185), smallData)
        XCTAssertEqual(cache.getCachedPoster(for: testFileId, size: .w500), largeData)
    }

    func testGetNonExistentPosterReturnsNil() {
        let result = cache.getCachedPoster(for: testFileId, size: .w342)
        XCTAssertNil(result)
    }

    func testPosterURLExistsAfterCaching() throws {
        let testData = "test".data(using: .utf8)!

        XCTAssertNil(cache.posterURL(for: testFileId, size: .w342))

        try cache.cachePoster(testData, for: testFileId, size: .w342)

        XCTAssertNotNil(cache.posterURL(for: testFileId, size: .w342))
    }

    // MARK: - Backdrop Caching

    func testCacheAndRetrieveBackdrop() throws {
        let testData = "test backdrop data".data(using: .utf8)!

        try cache.cacheBackdrop(testData, for: testFileId, size: .w780)
        let retrieved = cache.getCachedBackdrop(for: testFileId, size: .w780)

        XCTAssertEqual(retrieved, testData)
    }

    func testCacheMultipleBackdropSizes() throws {
        let smallData = "small".data(using: .utf8)!
        let largeData = "large".data(using: .utf8)!

        try cache.cacheBackdrop(smallData, for: testFileId, size: .w300)
        try cache.cacheBackdrop(largeData, for: testFileId, size: .w1280)

        XCTAssertEqual(cache.getCachedBackdrop(for: testFileId, size: .w300), smallData)
        XCTAssertEqual(cache.getCachedBackdrop(for: testFileId, size: .w1280), largeData)
    }

    func testGetNonExistentBackdropReturnsNil() {
        let result = cache.getCachedBackdrop(for: testFileId, size: .w780)
        XCTAssertNil(result)
    }

    func testBackdropURLExistsAfterCaching() throws {
        let testData = "test".data(using: .utf8)!

        XCTAssertNil(cache.backdropURL(for: testFileId, size: .w780))

        try cache.cacheBackdrop(testData, for: testFileId, size: .w780)

        XCTAssertNotNil(cache.backdropURL(for: testFileId, size: .w780))
    }

    // MARK: - Deletion

    func testDeleteArtworkRemovesAllSizes() throws {
        try cache.cachePoster("poster".data(using: .utf8)!, for: testFileId, size: .w342)
        try cache.cachePoster("poster2".data(using: .utf8)!, for: testFileId, size: .w500)
        try cache.cacheBackdrop("backdrop".data(using: .utf8)!, for: testFileId, size: .w780)

        try cache.deleteArtwork(for: testFileId)

        XCTAssertNil(cache.getCachedPoster(for: testFileId, size: .w342))
        XCTAssertNil(cache.getCachedPoster(for: testFileId, size: .w500))
        XCTAssertNil(cache.getCachedBackdrop(for: testFileId, size: .w780))
    }

    func testDeleteArtworkDoesNotAffectOtherFiles() throws {
        let otherFileId = UUID()

        try cache.cachePoster("poster1".data(using: .utf8)!, for: testFileId, size: .w342)
        try cache.cachePoster("poster2".data(using: .utf8)!, for: otherFileId, size: .w342)

        try cache.deleteArtwork(for: testFileId)

        XCTAssertNil(cache.getCachedPoster(for: testFileId, size: .w342))
        XCTAssertNotNil(cache.getCachedPoster(for: otherFileId, size: .w342))
    }

    func testDeleteAllArtwork() throws {
        let fileId1 = UUID()
        let fileId2 = UUID()

        try cache.cachePoster("p1".data(using: .utf8)!, for: fileId1, size: .w342)
        try cache.cachePoster("p2".data(using: .utf8)!, for: fileId2, size: .w342)
        try cache.cacheBackdrop("b1".data(using: .utf8)!, for: fileId1, size: .w780)

        try cache.deleteAllArtwork()

        XCTAssertNil(cache.getCachedPoster(for: fileId1, size: .w342))
        XCTAssertNil(cache.getCachedPoster(for: fileId2, size: .w342))
        XCTAssertNil(cache.getCachedBackdrop(for: fileId1, size: .w780))
    }

    // MARK: - Cache Size

    func testCacheSizeReturnsZeroWhenEmpty() throws {
        try cache.deleteAllArtwork()
        let size = try cache.cacheSize()
        XCTAssertEqual(size, 0)
    }

    func testCacheSizeIncreases() throws {
        try cache.deleteAllArtwork()
        let initialSize = try cache.cacheSize()

        // Cache some data
        let largeData = Data(repeating: 0, count: 1000)
        try cache.cachePoster(largeData, for: testFileId, size: .w342)

        let newSize = try cache.cacheSize()
        XCTAssertGreaterThan(newSize, initialSize)
        XCTAssertGreaterThanOrEqual(newSize, 1000)
    }

    func testFormattedCacheSize() throws {
        try cache.deleteAllArtwork()

        // Cache 1MB of data
        let megabyteData = Data(repeating: 0, count: 1024 * 1024)
        try cache.cachePoster(megabyteData, for: testFileId, size: .w342)

        let formatted = try cache.formattedCacheSize()
        XCTAssertTrue(formatted.contains("MB") || formatted.contains("KB"))
    }

    // MARK: - Size Constants

    func testPosterSizeDefaults() {
        XCTAssertEqual(PosterSize.grid, .w342)
        XCTAssertEqual(PosterSize.detail, .w500)
    }

    func testBackdropSizeDefaults() {
        XCTAssertEqual(BackdropSize.default, .w780)
        XCTAssertEqual(BackdropSize.tvOS, .w1280)
    }
}
