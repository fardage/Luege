import Foundation

/// Errors that can occur during video playback
public enum PlaybackError: Error, LocalizedError, Sendable, Equatable {
    case notConnected
    case fileNotFound(String)
    /// Format is not supported by the native player (e.g., MKV, AVI)
    case unsupportedFormat(String)
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
            return "\(format) format is not supported. Supported formats: MP4, M4V, MOV"
        case .networkError(let message):
            return "Network error: \(message)"
        case .playbackFailed(let reason):
            return "Playback failed: \(reason)"
        case .timeout:
            return "The operation timed out"
        }
    }
}
