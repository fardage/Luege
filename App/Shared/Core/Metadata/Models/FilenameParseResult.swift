import Foundation

/// Result of parsing movie information from a filename
struct FilenameParseResult: Sendable, Equatable {
    /// The extracted movie title
    let title: String

    /// The release year if found in the filename
    let year: Int?

    /// Quality indicator if found (e.g., "1080p", "4K", "720p")
    let quality: String?

    init(title: String, year: Int? = nil, quality: String? = nil) {
        self.title = title
        self.year = year
        self.quality = quality
    }
}
