import Foundation

/// Type of file system entry
public enum FileEntryType: String, Sendable, Codable, Equatable {
    case folder
    case file
    case symlink
    case unknown
}

/// Represents a file or folder entry in an SMB share
public struct FileEntry: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let path: String
    public let type: FileEntryType
    public let size: Int64?
    public let modifiedDate: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        type: FileEntryType,
        size: Int64? = nil,
        modifiedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.size = size
        self.modifiedDate = modifiedDate
    }

    /// Whether this entry is a folder
    public var isFolder: Bool {
        type == .folder
    }

    /// File extension (empty for folders)
    public var fileExtension: String {
        guard type == .file else { return "" }
        return (name as NSString).pathExtension.lowercased()
    }

    /// Video file extensions supported by the app
    public static let videoExtensions: Set<String> = [
        "mkv", "mp4", "avi", "mov", "wmv", "m4v", "ts", "webm"
    ]

    /// Whether this is a video file
    public var isVideoFile: Bool {
        guard type == .file else { return false }
        return Self.videoExtensions.contains(fileExtension)
    }

    /// Subtitle file extensions supported by the app
    public static let subtitleExtensions: Set<String> = [
        "srt", "ass", "sub", "ssa", "idx", "vtt"
    ]

    /// Whether this is a subtitle file
    public var isSubtitleFile: Bool {
        guard type == .file else { return false }
        return Self.subtitleExtensions.contains(fileExtension)
    }

    /// Filename without extension (for subtitle matching)
    public var baseFileName: String {
        (name as NSString).deletingPathExtension
    }

    /// Human-readable file size
    public var formattedSize: String? {
        guard let size = size, type == .file else { return nil }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// Human-readable modification date
    public var formattedDate: String? {
        guard let date = modifiedDate else { return nil }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
