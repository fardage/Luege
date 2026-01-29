import Foundation

/// Errors that can occur during video playback
public enum PlaybackError: Error, LocalizedError, Sendable, Equatable {
    case notConnected
    case fileNotFound(String)
    /// Format is not supported by any available player
    case unsupportedFormat(String)
    /// Video codec is not supported
    case unsupportedVideoCodec(codec: String, container: String)
    /// Audio codec is not supported
    case unsupportedAudioCodec(codec: String, container: String)
    /// VLCKit playback error
    case vlcError(String)
    /// VLCKit is not available on this platform
    case vlcNotAvailable
    case networkError(String)
    case playbackFailed(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to the share"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .unsupportedFormat(let format):
            return "\(format) format is not supported"
        case .unsupportedVideoCodec(let codec, let container):
            return "Video codec \(codec) in \(container) container is not supported"
        case .unsupportedAudioCodec(let codec, let container):
            return "Audio codec \(codec) in \(container) container is not supported"
        case .vlcError(let message):
            return "VLC playback error: \(message)"
        case .vlcNotAvailable:
            return "VLC player is not available. This format requires VLC to play."
        case .networkError(let message):
            return "Network error: \(message)"
        case .playbackFailed(let reason):
            return "Playback failed: \(reason)"
        case .timeout:
            return "The operation timed out"
        }
    }

    /// Whether this error represents an unsupported format/codec
    public var isUnsupportedMedia: Bool {
        switch self {
        case .unsupportedFormat, .unsupportedVideoCodec, .unsupportedAudioCodec, .vlcNotAvailable:
            return true
        default:
            return false
        }
    }
}
