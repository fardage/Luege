import Foundation

/// Analyzes media file formats based on file extension
/// Note: This implementation uses extension-based detection.
/// For more accurate codec detection, this could be extended to parse file headers.
public final class FormatAnalyzer: FormatAnalyzing, Sendable {

    public init() {}

    public func analyze(path: String) -> MediaFormat {
        let fileExtension = (path as NSString).pathExtension.lowercased()
        return analyzeByExtension(fileExtension)
    }

    public func analyze(file: FileEntry) -> MediaFormat {
        return analyzeByExtension(file.fileExtension)
    }

    /// Analyze format based on file extension
    /// - Parameter ext: Lowercase file extension
    /// - Returns: The detected media format with likely codecs
    private func analyzeByExtension(_ ext: String) -> MediaFormat {
        let container = ContainerFormat(fileExtension: ext)

        // Make educated guesses about codecs based on container
        let (videoCodec, audioCodecs) = likelyCodecs(for: container)

        return MediaFormat(
            container: container,
            videoCodec: videoCodec,
            audioCodecs: audioCodecs
        )
    }

    /// Get likely codecs for a container format
    /// These are educated guesses based on common encoding practices
    /// Returns empty arrays for unknown codecs (to allow native player attempt)
    private func likelyCodecs(for container: ContainerFormat) -> (VideoCodec, [AudioCodec]) {
        switch container {
        case .mp4, .m4v:
            // MP4/M4V typically use H.264/H.265 with AAC - assume native compatible
            return (.unknown, [])
        case .mov:
            // QuickTime can contain many codecs - assume native compatible
            return (.unknown, [])
        case .mkv:
            // MKV is very flexible, but container itself requires VLC
            return (.unknown, [])
        case .avi:
            // AVI often contains MPEG-4 or older codecs
            return (.unknown, [])
        case .wmv:
            // WMV uses Windows Media codecs (VC-1)
            return (.vc1, [])
        case .ts:
            // MPEG-TS typically uses H.264 with AC3 or AAC - assume native compatible
            return (.unknown, [])
        case .webm:
            // WebM uses VP8/VP9 with Vorbis/Opus
            return (.vp9, [.opus, .vorbis])
        case .unknown:
            return (.unknown, [])
        }
    }
}
