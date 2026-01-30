import Foundation

/// Content type classification for library folders
enum LibraryContentType: String, Codable, Sendable, CaseIterable, Identifiable {
    case movies
    case tvShows
    case homeVideos
    case other

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .movies:
            return "Movies"
        case .tvShows:
            return "TV Shows"
        case .homeVideos:
            return "Home Videos"
        case .other:
            return "Other"
        }
    }

    /// SF Symbol icon name for this content type
    var iconName: String {
        switch self {
        case .movies:
            return "film"
        case .tvShows:
            return "tv"
        case .homeVideos:
            return "video"
        case .other:
            return "folder"
        }
    }
}
