import Foundation

/// Represents a subtitle track within a media file
public struct SubtitleTrack: Identifiable, Sendable, Equatable {
    /// Unique identifier for this track
    public let id: String

    /// Index of this track (used for selection)
    public let index: Int

    /// ISO 639-1/639-2 language code (e.g., "en", "eng")
    public let languageCode: String?

    /// Human-readable language name (e.g., "English")
    public let languageName: String?

    /// Subtitle format
    public let format: SubtitleFormat

    /// Whether this is an embedded subtitle track (vs. external file)
    public let isEmbedded: Bool

    /// Whether this is the default subtitle track
    public let isDefault: Bool

    /// Whether this is a forced subtitle track (e.g., for foreign language parts)
    public let isForced: Bool

    public init(
        id: String,
        index: Int,
        languageCode: String? = nil,
        languageName: String? = nil,
        format: SubtitleFormat = .unknown,
        isEmbedded: Bool = true,
        isDefault: Bool = false,
        isForced: Bool = false
    ) {
        self.id = id
        self.index = index
        self.languageCode = languageCode
        self.languageName = languageName
        self.format = format
        self.isEmbedded = isEmbedded
        self.isDefault = isDefault
        self.isForced = isForced
    }

    /// Human-readable display name for the track (e.g., "English - SRT" or "English (Forced)")
    public var displayName: String {
        var parts: [String] = []

        // Language name or code
        if let name = languageName, !name.isEmpty {
            parts.append(name)
        } else if let code = languageCode, !code.isEmpty {
            // Try to get localized language name from code
            let localizedName = Locale.current.localizedString(forLanguageCode: code)
            parts.append(localizedName ?? code.uppercased())
        } else {
            parts.append("Track \(index + 1)")
        }

        // Add forced indicator
        if isForced {
            parts[0] += " (Forced)"
        }

        // Format info
        if format != .unknown {
            parts.append(format.displayName)
        }

        // External indicator
        if !isEmbedded {
            parts.append("External")
        }

        return parts.joined(separator: " - ")
    }
}

/// Subtitle format/codec types
public enum SubtitleFormat: String, Sendable, Equatable, CaseIterable {
    case srt
    case ass
    case ssa
    case sub
    case pgs
    case vobsub
    case webvtt
    case dvbsub
    case cc608
    case cc708
    case unknown

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .srt: return "SRT"
        case .ass: return "ASS"
        case .ssa: return "SSA"
        case .sub: return "SUB"
        case .pgs: return "PGS"
        case .vobsub: return "VobSub"
        case .webvtt: return "WebVTT"
        case .dvbsub: return "DVB"
        case .cc608: return "CC"
        case .cc708: return "CC"
        case .unknown: return ""
        }
    }

    /// Initialize from file extension
    public init(fromExtension ext: String) {
        switch ext.lowercased() {
        case "srt": self = .srt
        case "ass": self = .ass
        case "ssa": self = .ssa
        case "sub": self = .sub
        case "vtt": self = .webvtt
        case "idx": self = .vobsub
        default: self = .unknown
        }
    }
}
