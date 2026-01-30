import Foundation

/// Represents an audio track within a media file
public struct AudioTrack: Identifiable, Sendable, Equatable {
    /// Unique identifier for this track
    public let id: String

    /// Index of this track (used for selection)
    public let index: Int

    /// ISO 639-1/639-2 language code (e.g., "en", "eng")
    public let languageCode: String?

    /// Human-readable language name (e.g., "English")
    public let languageName: String?

    /// Audio codec used for this track
    public let codec: AudioCodec

    /// Number of audio channels (e.g., 2 for stereo, 6 for 5.1)
    public let channels: Int?

    /// Whether this is the default audio track
    public let isDefault: Bool

    public init(
        id: String,
        index: Int,
        languageCode: String? = nil,
        languageName: String? = nil,
        codec: AudioCodec = .unknown,
        channels: Int? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.index = index
        self.languageCode = languageCode
        self.languageName = languageName
        self.codec = codec
        self.channels = channels
        self.isDefault = isDefault
    }

    /// Human-readable display name for the track (e.g., "English - AC3 5.1")
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

        // Codec and channel info
        var codecPart = codec.shortDisplayName
        if let channels = channels {
            codecPart += " \(channelLayoutDescription(channels))"
        }
        if codec != .unknown || channels != nil {
            parts.append(codecPart)
        }

        return parts.joined(separator: " - ")
    }

    /// Returns a short description of the channel layout
    private func channelLayoutDescription(_ channels: Int) -> String {
        switch channels {
        case 1:
            return "Mono"
        case 2:
            return "Stereo"
        case 6:
            return "5.1"
        case 8:
            return "7.1"
        default:
            return "\(channels)ch"
        }
    }
}

// MARK: - AudioCodec Extension

extension AudioCodec {
    /// Short display name for use in audio track display
    public var shortDisplayName: String {
        switch self {
        case .aac: return "AAC"
        case .ac3: return "AC3"
        case .eac3: return "E-AC3"
        case .dts: return "DTS"
        case .truehd: return "TrueHD"
        case .flac: return "FLAC"
        case .mp3: return "MP3"
        case .opus: return "Opus"
        case .vorbis: return "Vorbis"
        case .unknown: return ""
        }
    }
}
