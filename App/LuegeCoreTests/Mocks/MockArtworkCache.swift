import Foundation
@testable import Luege

/// Mock implementation of ArtworkCaching for testing
final class MockArtworkCache: ArtworkCaching, @unchecked Sendable {
    private var posters: [String: Data] = [:]
    private var backdrops: [String: Data] = [:]

    var cachePosterCallCount = 0
    var cacheBackdropCallCount = 0
    var deleteCallCount = 0
    var shouldThrowOnCache = false

    private func posterKey(_ fileId: UUID, _ size: PosterSize) -> String {
        "\(fileId.uuidString)_\(size.rawValue)"
    }

    private func backdropKey(_ fileId: UUID, _ size: BackdropSize) -> String {
        "\(fileId.uuidString)_\(size.rawValue)"
    }

    func cachePoster(_ data: Data, for fileId: UUID, size: PosterSize) throws {
        cachePosterCallCount += 1
        if shouldThrowOnCache {
            throw MetadataError.cacheFailed("Mock cache error")
        }
        posters[posterKey(fileId, size)] = data
    }

    func cacheBackdrop(_ data: Data, for fileId: UUID, size: BackdropSize) throws {
        cacheBackdropCallCount += 1
        if shouldThrowOnCache {
            throw MetadataError.cacheFailed("Mock cache error")
        }
        backdrops[backdropKey(fileId, size)] = data
    }

    func getCachedPoster(for fileId: UUID, size: PosterSize) -> Data? {
        posters[posterKey(fileId, size)]
    }

    func getCachedBackdrop(for fileId: UUID, size: BackdropSize) -> Data? {
        backdrops[backdropKey(fileId, size)]
    }

    func posterURL(for fileId: UUID, size: PosterSize) -> URL? {
        guard posters[posterKey(fileId, size)] != nil else { return nil }
        return URL(fileURLWithPath: "/mock/posters/\(posterKey(fileId, size)).jpg")
    }

    func backdropURL(for fileId: UUID, size: BackdropSize) -> URL? {
        guard backdrops[backdropKey(fileId, size)] != nil else { return nil }
        return URL(fileURLWithPath: "/mock/backdrops/\(backdropKey(fileId, size)).jpg")
    }

    func deleteArtwork(for fileId: UUID) throws {
        deleteCallCount += 1
        for size in PosterSize.allCases {
            posters.removeValue(forKey: posterKey(fileId, size))
        }
        for size in BackdropSize.allCases {
            backdrops.removeValue(forKey: backdropKey(fileId, size))
        }
    }

    func deleteAllArtwork() throws {
        posters.removeAll()
        backdrops.removeAll()
    }

    func cacheSize() throws -> Int64 {
        let posterBytes = posters.values.reduce(0) { $0 + $1.count }
        let backdropBytes = backdrops.values.reduce(0) { $0 + $1.count }
        return Int64(posterBytes + backdropBytes)
    }

    /// Helper to pre-populate cache for tests
    func setPoster(_ data: Data, for fileId: UUID, size: PosterSize) {
        posters[posterKey(fileId, size)] = data
    }

    func setBackdrop(_ data: Data, for fileId: UUID, size: BackdropSize) {
        backdrops[backdropKey(fileId, size)] = data
    }
}
