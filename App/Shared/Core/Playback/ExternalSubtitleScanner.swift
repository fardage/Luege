import Foundation

/// Information about an external subtitle file
struct ExternalSubtitleFile: Sendable {
    let path: String
    let filename: String
    let format: SubtitleFormat
    let languageCode: String?
    let languageName: String?
}

/// Scans directories for external subtitle files matching a video file
struct ExternalSubtitleScanner {

    /// Supported subtitle file extensions
    static let supportedExtensions = Set(["srt", "ass", "ssa", "sub", "vtt", "webvtt"])

    /// Scans a list of files for subtitle files that match the given video filename
    /// - Parameters:
    ///   - videoFilename: The video filename (e.g., "Movie.mp4")
    ///   - directoryFiles: List of FileEntry items in the same directory
    /// - Returns: Array of external subtitle files found
    static func findSubtitles(
        forVideo videoFilename: String,
        inDirectory directoryFiles: [FileEntry]
    ) -> [ExternalSubtitleFile] {
        // Get the base name of the video (without extension)
        let videoBaseName = (videoFilename as NSString).deletingPathExtension.lowercased()

        var subtitles: [ExternalSubtitleFile] = []

        for file in directoryFiles {
            // Skip non-files
            guard file.type == .file else { continue }

            // Check if this is a subtitle file
            let ext = (file.name as NSString).pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else { continue }

            // Check if the subtitle matches the video name
            // Subtitles can be: MovieName.srt, MovieName.en.srt, MovieName.English.srt
            let subtitleBaseName = (file.name as NSString).deletingPathExtension.lowercased()

            // The subtitle base name should start with the video base name
            guard subtitleBaseName.hasPrefix(videoBaseName) else { continue }

            // Parse language info from the remaining part of the filename
            let (languageCode, languageName) = parseLanguageInfo(
                subtitleName: subtitleBaseName,
                videoBaseName: videoBaseName
            )

            let format = SubtitleFormat(fromExtension: ext)

            subtitles.append(ExternalSubtitleFile(
                path: file.path,
                filename: file.name,
                format: format,
                languageCode: languageCode,
                languageName: languageName
            ))
        }

        // Sort by filename for consistent ordering
        return subtitles.sorted { $0.filename < $1.filename }
    }

    /// Parse language information from subtitle filename
    /// Examples:
    ///   - "MovieName.en.srt" -> ("en", nil)
    ///   - "MovieName.English.srt" -> (nil, "English")
    ///   - "MovieName.eng.srt" -> ("eng", nil)
    ///   - "MovieName.srt" -> (nil, nil)
    private static func parseLanguageInfo(
        subtitleName: String,
        videoBaseName: String
    ) -> (languageCode: String?, languageName: String?) {
        // Remove the video base name from the subtitle name
        var remainder = subtitleName
        if remainder.hasPrefix(videoBaseName) {
            remainder = String(remainder.dropFirst(videoBaseName.count))
        }

        // Remove leading dots/separators
        remainder = remainder.trimmingCharacters(in: CharacterSet(charactersIn: "._- "))

        // If there's another extension (from double extension like .en.srt), remove it
        if let dotIndex = remainder.lastIndex(of: ".") {
            remainder = String(remainder[..<dotIndex])
        }

        guard !remainder.isEmpty else {
            return (nil, nil)
        }

        // Check if it's a known language code (2-3 characters)
        let lowercased = remainder.lowercased()
        if remainder.count <= 3 {
            // Likely a language code
            if let displayName = Locale.current.localizedString(forLanguageCode: lowercased) {
                return (lowercased, displayName)
            }
            return (lowercased, nil)
        }

        // Check if it matches common language names
        let knownLanguages: [String: String] = [
            "english": "en",
            "spanish": "es",
            "french": "fr",
            "german": "de",
            "italian": "it",
            "portuguese": "pt",
            "russian": "ru",
            "japanese": "ja",
            "korean": "ko",
            "chinese": "zh",
            "arabic": "ar",
            "dutch": "nl",
            "polish": "pl",
            "swedish": "sv",
            "norwegian": "no",
            "danish": "da",
            "finnish": "fi",
            "turkish": "tr",
            "greek": "el",
            "hebrew": "he",
            "thai": "th",
            "vietnamese": "vi",
            "indonesian": "id",
            "hindi": "hi"
        ]

        if let code = knownLanguages[lowercased] {
            // Return both the code and a properly capitalized name
            return (code, remainder.capitalized)
        }

        // Unknown - return as language name
        return (nil, remainder.capitalized)
    }
}
