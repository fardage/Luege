import Foundation

/// Represents the playback progress for a media file
struct PlaybackProgress: Codable, Sendable, Equatable {
    let fileId: UUID
    var currentTime: TimeInterval
    var duration: TimeInterval
    var isWatched: Bool
    var lastPlayedAt: Date
    var updatedAt: Date

    /// Threshold at which a file is automatically marked as watched (90%)
    static let watchedThreshold = 0.90

    /// Progress fraction (0.0–1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(currentTime / duration, 1.0)
    }

    /// Whether the file can be resumed (not watched, played past 30s, and under 90%)
    var isResumable: Bool {
        !isWatched && currentTime > 30 && progress < Self.watchedThreshold
    }

    /// Formatted resume time string (e.g. "1:23:45")
    var formattedResumeTime: String {
        let totalSeconds = Int(currentTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
