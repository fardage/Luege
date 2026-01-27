import Foundation

/// Represents the current state of video playback
public enum PlaybackState: Sendable, Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case buffering
    case error(PlaybackError)

    public var isActive: Bool {
        switch self {
        case .playing, .paused, .buffering:
            return true
        default:
            return false
        }
    }

    public var canPlay: Bool {
        switch self {
        case .ready, .paused:
            return true
        default:
            return false
        }
    }

    public var canPause: Bool {
        switch self {
        case .playing, .buffering:
            return true
        default:
            return false
        }
    }
}
