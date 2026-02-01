import Foundation

/// Represents a subtitle track within a media file or an external subtitle file
struct SubtitleTrack: Identifiable, Sendable, Equatable {
    /// Unique identifier for this track
    let id: String

    /// Index of this track in our array (used for UI selection)
    let index: Int

    /// The actual VLC track index (used when selecting in VLC)
    let vlcIndex: Int32

    /// ISO 639-1/639-2 language code (e.g., "en", "eng")
    let languageCode: String?

    /// Human-readable language name (e.g., "English")
    let languageName: String?

    /// Whether this is the default subtitle track
    let isDefault: Bool

    /// Whether this is an external subtitle file (vs embedded in the video)
    let isExternal: Bool

    /// Path to the external subtitle file (relative to share root)
    let externalPath: String?

    /// File format for external subtitles
    let format: SubtitleFormat?

    init(
        id: String,
        index: Int,
        vlcIndex: Int32 = 0,
        languageCode: String? = nil,
        languageName: String? = nil,
        isDefault: Bool = false,
        isExternal: Bool = false,
        externalPath: String? = nil,
        format: SubtitleFormat? = nil
    ) {
        self.id = id
        self.index = index
        self.vlcIndex = vlcIndex
        self.languageCode = languageCode
        self.languageName = languageName
        self.isDefault = isDefault
        self.isExternal = isExternal
        self.externalPath = externalPath
        self.format = format
    }

    /// Human-readable display name for the track (e.g., "English")
    var displayName: String {
        var name: String

        // Language name or code
        if let langName = languageName, !langName.isEmpty {
            name = langName
        } else if let code = languageCode, !code.isEmpty {
            // Try to get localized language name from code
            let localizedName = Locale.current.localizedString(forLanguageCode: code)
            name = localizedName ?? code.uppercased()
        } else {
            name = "Track \(index + 1)"
        }

        // Add format for external subtitles
        if isExternal, let format = format {
            name += " [\(format.displayName)]"
        }

        return name
    }
}

/// Supported subtitle file formats
enum SubtitleFormat: String, Sendable, Equatable, CaseIterable {
    case srt
    case ass
    case ssa
    case sub
    case vtt
    case unknown

    var displayName: String {
        switch self {
        case .srt: return "SRT"
        case .ass: return "ASS"
        case .ssa: return "SSA"
        case .sub: return "SUB"
        case .vtt: return "VTT"
        case .unknown: return "SUB"
        }
    }

    /// File extensions for this format
    var fileExtensions: [String] {
        switch self {
        case .srt: return ["srt"]
        case .ass: return ["ass"]
        case .ssa: return ["ssa"]
        case .sub: return ["sub"]
        case .vtt: return ["vtt", "webvtt"]
        case .unknown: return []
        }
    }

    /// All supported subtitle file extensions
    static var allExtensions: [String] {
        allCases.flatMap { $0.fileExtensions }
    }

    /// Initialize from file extension
    init(fromExtension ext: String) {
        let lowercased = ext.lowercased()
        self = SubtitleFormat.allCases.first { $0.fileExtensions.contains(lowercased) } ?? .unknown
    }
}
