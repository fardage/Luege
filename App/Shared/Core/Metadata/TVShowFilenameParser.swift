import Foundation

/// Parses TV show information from filenames
struct TVShowFilenameParser: Sendable {
    /// Quality indicators to look for in filenames
    private static let qualityPatterns: [(pattern: String, quality: String)] = [
        ("4K", "4K"),
        ("2160p", "4K"),
        ("UHD", "4K"),
        ("1080p", "1080p"),
        ("720p", "720p"),
        ("480p", "480p"),
        ("HDTV", "HDTV"),
        ("BluRay", "BluRay"),
        ("BDRip", "BDRip"),
        ("DVDRip", "DVDRip"),
        ("WEBRip", "WEBRip"),
        ("WEBDL", "WEB-DL"),
        ("WEB-DL", "WEB-DL")
    ]

    /// Words that typically appear after the show title
    private static let stopWords: Set<String> = [
        "bluray", "bdrip", "brrip", "dvdrip", "webrip", "webdl", "web-dl",
        "hdtv", "hdrip", "x264", "x265", "h264", "h265", "hevc", "avc",
        "xvid", "divx", "mkv", "avi", "mp4", "m4v", "mov",
        "1080p", "720p", "480p", "2160p", "4k", "uhd",
        "proper", "repack", "internal", "limited",
        "hdr", "hdr10", "dolby", "vision", "atmos",
        "dts", "aac", "ac3", "flac", "truehd", "dd5", "dd2",
        "multi", "dual", "audio", "subbed", "dubbed",
        "yify", "yts", "rarbg", "ettv", "eztv", "lol", "dimension"
    ]

    /// Parse a filename to extract TV show information
    /// - Parameter filename: The filename to parse (with or without extension)
    /// - Returns: Parsed result with show name, season, episode, and quality
    func parse(_ filename: String) -> TVShowParseResult {
        // Remove file extension
        let nameWithoutExtension = removeExtension(from: filename)

        // Extract quality before processing
        let quality = extractQuality(from: nameWithoutExtension)

        // Try to extract season/episode info using various patterns
        // Multi-episode patterns must be tried BEFORE standard pattern
        // since standard pattern would match partial (e.g., S01E03 from S01E03-E04)
        if let result = tryMultiEpisodePattern(nameWithoutExtension, quality: quality) {
            return result
        }

        if let result = tryStandardPattern(nameWithoutExtension, quality: quality) {
            return result
        }

        if let result = tryAlternativePattern(nameWithoutExtension, quality: quality) {
            return result
        }

        if let result = tryVerbosePattern(nameWithoutExtension, quality: quality) {
            return result
        }

        // No TV pattern found - return just the cleaned name
        let cleanedName = cleanTitle(nameWithoutExtension)
        return TVShowParseResult(showName: cleanedName, quality: quality)
    }

    /// Check if a filename appears to be a TV show
    func isTVShow(_ filename: String) -> Bool {
        let result = parse(filename)
        return result.isValid
    }

    // MARK: - Pattern Matching

    /// Standard pattern: Show.Name.S01E03 or Show Name S01E03
    private func tryStandardPattern(_ name: String, quality: String?) -> TVShowParseResult? {
        // Pattern: S followed by 1-2 digits, E followed by 1-3 digits
        // Supports: S01E03, S1E3, S01E103 (for shows with 100+ episodes)
        let pattern = #"(.+?)[.\s_-][Ss](\d{1,2})[Ee](\d{1,3})(?![0-9])"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) else {
            return nil
        }

        guard let showRange = Range(match.range(at: 1), in: name),
              let seasonRange = Range(match.range(at: 2), in: name),
              let episodeRange = Range(match.range(at: 3), in: name) else {
            return nil
        }

        let showName = cleanTitle(String(name[showRange]))
        let season = Int(name[seasonRange])
        let episode = Int(name[episodeRange])

        return TVShowParseResult(
            showName: showName,
            season: season,
            episode: episode,
            quality: quality
        )
    }

    /// Multi-episode pattern: Show.Name.S01E03-E04 or S01E03E04
    private func tryMultiEpisodePattern(_ name: String, quality: String?) -> TVShowParseResult? {
        // Pattern 1: S01E03-E04 or S01E03-04
        let dashPattern = #"(.+?)[.\s_-][Ss](\d{1,2})[Ee](\d{1,3})-[Ee]?(\d{1,3})(?![0-9])"#

        if let regex = try? NSRegularExpression(pattern: dashPattern, options: []),
           let match = regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) {

            guard let showRange = Range(match.range(at: 1), in: name),
                  let seasonRange = Range(match.range(at: 2), in: name),
                  let episodeRange = Range(match.range(at: 3), in: name),
                  let endRange = Range(match.range(at: 4), in: name) else {
                return nil
            }

            let showName = cleanTitle(String(name[showRange]))
            let season = Int(name[seasonRange])
            let episode = Int(name[episodeRange])
            let episodeEnd = Int(name[endRange])

            return TVShowParseResult(
                showName: showName,
                season: season,
                episode: episode,
                episodeEnd: episodeEnd,
                quality: quality
            )
        }

        // Pattern 2: S01E03E04 (no separator)
        let consecutivePattern = #"(.+?)[.\s_-][Ss](\d{1,2})[Ee](\d{1,3})[Ee](\d{1,3})(?![0-9])"#

        if let regex = try? NSRegularExpression(pattern: consecutivePattern, options: []),
           let match = regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) {

            guard let showRange = Range(match.range(at: 1), in: name),
                  let seasonRange = Range(match.range(at: 2), in: name),
                  let episodeRange = Range(match.range(at: 3), in: name),
                  let endRange = Range(match.range(at: 4), in: name) else {
                return nil
            }

            let showName = cleanTitle(String(name[showRange]))
            let season = Int(name[seasonRange])
            let episode = Int(name[episodeRange])
            let episodeEnd = Int(name[endRange])

            return TVShowParseResult(
                showName: showName,
                season: season,
                episode: episode,
                episodeEnd: episodeEnd,
                quality: quality
            )
        }

        return nil
    }

    /// Alternative pattern: Show.Name.1x03
    private func tryAlternativePattern(_ name: String, quality: String?) -> TVShowParseResult? {
        // Pattern: digit(s) x digit(s)
        let pattern = #"(.+?)[.\s_-](\d{1,2})x(\d{1,3})(?![0-9])"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) else {
            return nil
        }

        guard let showRange = Range(match.range(at: 1), in: name),
              let seasonRange = Range(match.range(at: 2), in: name),
              let episodeRange = Range(match.range(at: 3), in: name) else {
            return nil
        }

        let showName = cleanTitle(String(name[showRange]))
        let season = Int(name[seasonRange])
        let episode = Int(name[episodeRange])

        return TVShowParseResult(
            showName: showName,
            season: season,
            episode: episode,
            quality: quality
        )
    }

    /// Verbose pattern: Show Name Season 1 Episode 3
    private func tryVerbosePattern(_ name: String, quality: String?) -> TVShowParseResult? {
        // Case-insensitive pattern for "Season X Episode Y"
        let pattern = #"(.+?)[.\s_-]Season[.\s_-]?(\d{1,2})[.\s_-]Episode[.\s_-]?(\d{1,3})"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) else {
            return nil
        }

        guard let showRange = Range(match.range(at: 1), in: name),
              let seasonRange = Range(match.range(at: 2), in: name),
              let episodeRange = Range(match.range(at: 3), in: name) else {
            return nil
        }

        let showName = cleanTitle(String(name[showRange]))
        let season = Int(name[seasonRange])
        let episode = Int(name[episodeRange])

        return TVShowParseResult(
            showName: showName,
            season: season,
            episode: episode,
            quality: quality
        )
    }

    // MARK: - Helper Methods

    /// Remove file extension from filename
    private func removeExtension(from filename: String) -> String {
        let videoExtensions = ["mkv", "mp4", "m4v", "mov", "avi", "wmv", "flv", "webm", "ts", "m2ts"]
        let lowercased = filename.lowercased()

        for ext in videoExtensions {
            if lowercased.hasSuffix(".\(ext)") {
                let endIndex = filename.index(filename.endIndex, offsetBy: -(ext.count + 1))
                return String(filename[..<endIndex])
            }
        }
        return filename
    }

    /// Extract quality indicator from filename
    private func extractQuality(from name: String) -> String? {
        let lowercased = name.lowercased()
        for (pattern, quality) in Self.qualityPatterns {
            if lowercased.contains(pattern.lowercased()) {
                return quality
            }
        }
        return nil
    }

    /// Clean up title by replacing separators and removing junk
    private func cleanTitle(_ raw: String) -> String {
        var title = raw

        // Replace dots and underscores with spaces
        title = title.replacingOccurrences(of: ".", with: " ")
        title = title.replacingOccurrences(of: "_", with: " ")

        // Handle hyphens - replace if surrounded by spaces or at word boundaries
        title = replaceHyphenSeparators(in: title)

        // Handle year in parentheses at end of show name - preserve it
        // e.g., "Show Name (2020)" should remain "Show Name (2020)"

        // Split into words and filter out stop words/quality indicators
        let words = title.components(separatedBy: .whitespaces)
        var cleanedWords: [String] = []

        for word in words {
            let lowercased = word.lowercased()

            // Skip empty words
            if word.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            // Stop if we hit a known stop word
            if Self.stopWords.contains(lowercased) {
                break
            }

            // Skip quality patterns
            if Self.qualityPatterns.contains(where: { $0.pattern.lowercased() == lowercased }) {
                break
            }

            cleanedWords.append(word)
        }

        title = cleanedWords.joined(separator: " ")

        // Collapse multiple spaces
        while title.contains("  ") {
            title = title.replacingOccurrences(of: "  ", with: " ")
        }

        return title.trimmingCharacters(in: .whitespaces)
    }

    /// Replace hyphens that act as word separators while preserving those within compound words
    private func replaceHyphenSeparators(in text: String) -> String {
        // If text already contains spaces, preserve hyphens (they're part of compound words)
        if text.contains(" ") {
            return text
        }

        // Count hyphens to determine if they're separators
        let hyphenCount = text.filter { $0 == "-" }.count

        // If there are 3+ hyphens, it's almost certainly a separator-based filename
        if hyphenCount >= 3 {
            return text.replacingOccurrences(of: "-", with: " ")
        }

        // For fewer hyphens, try to be smart about compound words
        var result = ""
        let chars = Array(text)

        for i in 0..<chars.count {
            let char = chars[i]
            if char == "-" {
                let prevWord = extractWordBefore(chars: chars, index: i)
                let nextWord = extractWordAfter(chars: chars, index: i)

                if isLikelyCompound(prev: prevWord, next: nextWord) {
                    result.append(char)
                } else {
                    result.append(" ")
                }
            } else {
                result.append(char)
            }
        }

        return result
    }

    private func extractWordBefore(chars: [Character], index: Int) -> String {
        var word = ""
        var i = index - 1
        while i >= 0 && (chars[i].isLetter || chars[i].isNumber) {
            word = String(chars[i]) + word
            i -= 1
        }
        return word
    }

    private func extractWordAfter(chars: [Character], index: Int) -> String {
        var word = ""
        var i = index + 1
        while i < chars.count && (chars[i].isLetter || chars[i].isNumber) {
            word += String(chars[i])
            i += 1
        }
        return word
    }

    private func isLikelyCompound(prev: String, next: String) -> Bool {
        guard !prev.isEmpty, !next.isEmpty else { return false }

        // Single letter prefix like "X-Files", "T-Rex"
        if prev.count == 1 && prev.first?.isUppercase == true {
            return true
        }

        // Common TV show compound patterns
        let compoundPatterns = [
            ("star", "trek"), ("star", "wars"), ("law", "order"),
            ("spider", "man"), ("bat", "man"), ("iron", "man"),
            ("sci", "fi"), ("self", ""), ("non", "")
        ]

        let prevLower = prev.lowercased()
        let nextLower = next.lowercased()

        for (prefix, suffix) in compoundPatterns {
            if prevLower == prefix && (suffix.isEmpty || nextLower == suffix) {
                return true
            }
        }

        return false
    }
}
