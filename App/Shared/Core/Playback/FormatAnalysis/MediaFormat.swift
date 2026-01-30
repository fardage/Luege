import Foundation

/// Represents a media container format
enum ContainerFormat: String, Sendable, Equatable, CaseIterable {
    case mp4
    case m4v
    case mov
    case mkv
    case avi
    case wmv
    case ts
    case webm
    case unknown

    /// Initialize from file extension
    init(fileExtension: String) {
        let ext = fileExtension.lowercased()
        self = ContainerFormat(rawValue: ext) ?? .unknown
    }

    /// Whether this format is natively supported by AVPlayer
    var isNativelySupported: Bool {
        switch self {
        case .mp4, .m4v, .mov, .ts:
            return true
        case .mkv, .avi, .wmv, .webm, .unknown:
            return false
        }
    }

    /// Whether VLCKit should be used for this format
    var requiresVLC: Bool {
        !isNativelySupported
    }

    /// Human-readable format name
    var displayName: String {
        switch self {
        case .mp4: return "MP4"
        case .m4v: return "M4V"
        case .mov: return "QuickTime"
        case .mkv: return "Matroska"
        case .avi: return "AVI"
        case .wmv: return "Windows Media"
        case .ts: return "MPEG-TS"
        case .webm: return "WebM"
        case .unknown: return "Unknown"
        }
    }
}

/// Represents a video codec
enum VideoCodec: String, Sendable, Equatable, CaseIterable {
    case h264
    case h265
    case vp9
    case vp8
    case mpeg4
    case vc1
    case unknown

    /// Whether this codec is natively supported by AVPlayer
    var isNativelySupported: Bool {
        switch self {
        case .h264, .h265:
            return true
        case .vp9, .vp8, .mpeg4, .vc1, .unknown:
            return false
        }
    }

    /// Human-readable codec name
    var displayName: String {
        switch self {
        case .h264: return "H.264"
        case .h265: return "H.265/HEVC"
        case .vp9: return "VP9"
        case .vp8: return "VP8"
        case .mpeg4: return "MPEG-4"
        case .vc1: return "VC-1"
        case .unknown: return "Unknown"
        }
    }
}

/// Represents an audio codec
enum AudioCodec: String, Sendable, Equatable, CaseIterable {
    case aac
    case ac3
    case eac3
    case dts
    case truehd
    case flac
    case mp3
    case opus
    case vorbis
    case unknown

    /// Whether this codec is natively supported by AVPlayer
    var isNativelySupported: Bool {
        switch self {
        case .aac, .ac3, .mp3:
            return true
        case .eac3:
            // E-AC3 is supported on iOS/tvOS for Dolby Digital Plus
            return true
        case .dts, .truehd, .flac, .opus, .vorbis, .unknown:
            return false
        }
    }

    /// Human-readable codec name
    var displayName: String {
        switch self {
        case .aac: return "AAC"
        case .ac3: return "Dolby Digital (AC3)"
        case .eac3: return "Dolby Digital Plus (E-AC3)"
        case .dts: return "DTS"
        case .truehd: return "Dolby TrueHD"
        case .flac: return "FLAC"
        case .mp3: return "MP3"
        case .opus: return "Opus"
        case .vorbis: return "Vorbis"
        case .unknown: return "Unknown"
        }
    }
}

/// Represents the complete media format information for a file
struct MediaFormat: Sendable, Equatable {
    let container: ContainerFormat
    let videoCodec: VideoCodec
    let audioCodecs: [AudioCodec]

    init(
        container: ContainerFormat,
        videoCodec: VideoCodec = .unknown,
        audioCodecs: [AudioCodec] = []
    ) {
        self.container = container
        self.videoCodec = videoCodec
        self.audioCodecs = audioCodecs
    }

    /// Whether this format can be played with AVPlayer
    var canUseNativePlayer: Bool {
        // Container must be supported
        guard container.isNativelySupported else { return false }
        // Video codec must be supported (if known)
        if videoCodec != .unknown && !videoCodec.isNativelySupported { return false }
        // At least one audio codec must be supported (if any are known)
        if !audioCodecs.isEmpty && !audioCodecs.contains(where: { $0.isNativelySupported }) {
            return false
        }
        return true
    }

    /// Whether VLCKit is required to play this format
    var requiresVLC: Bool {
        !canUseNativePlayer
    }

    /// Human-readable format description
    var description: String {
        var parts: [String] = [container.displayName]
        if videoCodec != .unknown {
            parts.append(videoCodec.displayName)
        }
        let audioNames = audioCodecs.filter { $0 != .unknown }.map { $0.displayName }
        if !audioNames.isEmpty {
            parts.append(audioNames.joined(separator: "/"))
        }
        return parts.joined(separator: " + ")
    }
}
