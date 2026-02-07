import Foundation

/// Service for managing playback progress with in-memory cache and persistent storage
@MainActor
final class PlaybackProgressService: ObservableObject {
    /// Incremented on every mutation to trigger view refreshes
    @Published private(set) var progressVersion: Int = 0

    private let storage: PlaybackProgressStoring
    private var cache: [UUID: PlaybackProgress] = [:]

    init(storage: PlaybackProgressStoring? = nil) {
        self.storage = storage ?? PlaybackProgressStorage()
        loadCache()
    }

    // MARK: - Public API

    /// Get progress for a file
    func progress(for fileId: UUID) -> PlaybackProgress? {
        cache[fileId]
    }

    /// Save playback progress, auto-marking as watched at 90%
    func saveProgress(fileId: UUID, currentTime: TimeInterval, duration: TimeInterval) {
        let now = Date()
        let watched = duration > 0 && (currentTime / duration) >= PlaybackProgress.watchedThreshold

        var entry = cache[fileId] ?? PlaybackProgress(
            fileId: fileId,
            currentTime: currentTime,
            duration: duration,
            isWatched: false,
            lastPlayedAt: now,
            updatedAt: now
        )

        entry.currentTime = currentTime
        entry.duration = duration
        entry.lastPlayedAt = now
        entry.updatedAt = now

        if watched {
            entry.isWatched = true
        }

        cache[fileId] = entry
        progressVersion += 1
        persistInBackground(entry)
    }

    /// Toggle watched state
    func toggleWatched(for fileId: UUID) {
        guard var entry = cache[fileId] else { return }
        entry.isWatched.toggle()
        entry.updatedAt = Date()
        cache[fileId] = entry
        progressVersion += 1
        persistInBackground(entry)
    }

    /// Mark as watched
    func markAsWatched(fileId: UUID) {
        let now = Date()
        var entry = cache[fileId] ?? PlaybackProgress(
            fileId: fileId,
            currentTime: 0,
            duration: 0,
            isWatched: true,
            lastPlayedAt: now,
            updatedAt: now
        )

        entry.isWatched = true
        entry.updatedAt = now
        cache[fileId] = entry
        progressVersion += 1
        persistInBackground(entry)
    }

    /// Mark as unwatched
    func markAsUnwatched(fileId: UUID) {
        guard var entry = cache[fileId] else { return }
        entry.isWatched = false
        entry.updatedAt = Date()
        cache[fileId] = entry
        progressVersion += 1
        persistInBackground(entry)
    }

    /// Check if a file is watched
    func isWatched(_ fileId: UUID) -> Bool {
        cache[fileId]?.isWatched ?? false
    }

    /// Check if a file is resumable
    func isResumable(_ fileId: UUID) -> Bool {
        cache[fileId]?.isResumable ?? false
    }

    /// Get all resumable items sorted by last played date (most recent first)
    func resumableItems() -> [PlaybackProgress] {
        cache.values
            .filter { $0.isResumable }
            .sorted { $0.lastPlayedAt > $1.lastPlayedAt }
    }

    /// Delete progress for a file (e.g., remove from Continue Watching)
    func deleteProgress(for fileId: UUID) {
        cache.removeValue(forKey: fileId)
        progressVersion += 1
        let storage = self.storage
        Task.detached { try? storage.delete(for: fileId) }
    }

    // MARK: - Private

    private func loadCache() {
        do {
            cache = try storage.loadAll()
        } catch {
            print("[PlaybackProgressService] Failed to load cache: \(error)")
        }
    }

    private func persistInBackground(_ progress: PlaybackProgress) {
        let storage = self.storage
        Task.detached {
            try? storage.save(progress)
        }
    }
}
