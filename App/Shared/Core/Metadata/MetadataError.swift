import Foundation

/// Errors that can occur during metadata operations
enum MetadataError: Error, LocalizedError, Sendable, Equatable {
    case apiKeyNotConfigured
    case invalidAPIKey
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case rateLimited
    case movieNotFound
    case parsingFailed(String)
    case storageFailed(String)
    case cacheFailed(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "TMDb API key is not configured. Please add your API key in Settings."
        case .invalidAPIKey:
            return "The TMDb API key is invalid"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let statusCode, let message):
            return "TMDb API error (\(statusCode)): \(message)"
        case .rateLimited:
            return "TMDb rate limit exceeded. Please try again later."
        case .movieNotFound:
            return "Movie not found on TMDb"
        case .parsingFailed(let message):
            return "Failed to parse response: \(message)"
        case .storageFailed(let message):
            return "Failed to save metadata: \(message)"
        case .cacheFailed(let message):
            return "Failed to cache artwork: \(message)"
        }
    }
}
