import Foundation

/// Represents the current state of video playback
enum PlaybackState: Sendable, Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case buffering
    case error(PlaybackError)

    var isActive: Bool {
        switch self {
        case .playing, .paused, .buffering:
            return true
        default:
            return false
        }
    }

    var canPlay: Bool {
        switch self {
        case .ready, .paused:
            return true
        default:
            return false
        }
    }

    var canPause: Bool {
        switch self {
        case .playing, .buffering:
            return true
        default:
            return false
        }
    }
}
