import Foundation

/// Parses movie information from filenames
struct FilenameParser: Sendable {
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
        ("WEBDL", "WEBDL"),
        ("WEB-DL", "WEB-DL")
    ]

    /// Words that typically appear after the movie title and year
    private static let stopWords: Set<String> = [
        "bluray", "bdrip", "brrip", "dvdrip", "webrip", "webdl", "web-dl",
        "hdtv", "hdrip", "x264", "x265", "h264", "h265", "hevc", "avc",
        "xvid", "divx", "mkv", "avi", "mp4", "m4v", "mov",
        "1080p", "720p", "480p", "2160p", "4k", "uhd",
        "extended", "unrated", "directors", "cut", "remastered",
        "proper", "repack", "internal", "limited", "theatrical",
        "imax", "3d", "hdr", "hdr10", "dolby", "vision", "atmos",
        "dts", "aac", "ac3", "flac", "truehd", "dd5", "dd2",
        "multi", "dual", "audio", "subbed", "dubbed",
        "yify", "yts", "rarbg", "sparks", "geckos", "fgt"
    ]

    /// Parse a filename to extract movie title, year, and quality
    /// - Parameter filename: The filename to parse (with or without extension)
    /// - Returns: Parsed result with title and optional year/quality
    func parse(_ filename: String) -> FilenameParseResult {
        // Remove file extension
        let nameWithoutExtension = removeExtension(from: filename)

        // Extract quality before processing
        let quality = extractQuality(from: nameWithoutExtension)

        // Try to find year pattern like (1999) or .1999. or [1999]
        let (titlePart, year) = extractTitleAndYear(from: nameWithoutExtension)

        // Clean up the title
        let cleanedTitle = cleanTitle(titlePart)

        return FilenameParseResult(title: cleanedTitle, year: year, quality: quality)
    }

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

    /// Extract title and year from filename
    private func extractTitleAndYear(from name: String) -> (String, Int?) {
        // Pattern 1: Year in parentheses "The Matrix (1999)"
        if let match = name.range(of: #"\s*\((\d{4})\)"#, options: .regularExpression) {
            let titlePart = String(name[..<match.lowerBound])
            let yearString = name[match].replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let year = Int(yearString), isValidYear(year) {
                return (titlePart, year)
            }
        }

        // Pattern 2: Year in brackets "The Matrix [1999]"
        if let match = name.range(of: #"\s*\[(\d{4})\]"#, options: .regularExpression) {
            let titlePart = String(name[..<match.lowerBound])
            let yearString = name[match].replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let year = Int(yearString), isValidYear(year) {
                return (titlePart, year)
            }
        }

        // Pattern 3: Year separated by dots/spaces "The.Matrix.1999" or "The Matrix 1999"
        // Look for a 4-digit year that's likely a year (1900-2099)
        let yearPattern = #"[\.\s_-](\d{4})[\.\s_-]"#
        if let regex = try? NSRegularExpression(pattern: yearPattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) {
            let yearRange = Range(match.range(at: 1), in: name)!
            if let year = Int(name[yearRange]), isValidYear(year) {
                let titleEndIndex = name.index(yearRange.lowerBound, offsetBy: -1, limitedBy: name.startIndex) ?? name.startIndex
                let titlePart = String(name[..<titleEndIndex])
                return (titlePart, year)
            }
        }

        // Pattern 4: Year at the end "The Matrix 1999" (no trailing separator)
        let endYearPattern = #"[\.\s_-](\d{4})$"#
        if let regex = try? NSRegularExpression(pattern: endYearPattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) {
            let yearRange = Range(match.range(at: 1), in: name)!
            if let year = Int(name[yearRange]), isValidYear(year) {
                let titleEndIndex = name.index(yearRange.lowerBound, offsetBy: -1, limitedBy: name.startIndex) ?? name.startIndex
                let titlePart = String(name[..<titleEndIndex])
                return (titlePart, year)
            }
        }

        return (name, nil)
    }

    /// Clean up title by replacing separators and removing junk
    private func cleanTitle(_ raw: String) -> String {
        var title = raw

        // Replace dots and underscores with spaces (these are always separators)
        title = title.replacingOccurrences(of: ".", with: " ")
        title = title.replacingOccurrences(of: "_", with: " ")

        // Handle hyphens: only treat as separators if they're between spaces/word boundaries
        // This preserves titles like "Spider-Man" while converting "The-Matrix-1999"
        title = replaceHyphenSeparators(in: title)

        // Split into words and filter out stop words/quality indicators
        let words = title.components(separatedBy: .whitespaces)
        var cleanedWords: [String] = []

        for word in words {
            let lowercased = word.lowercased()

            // Stop if we hit a known stop word
            if Self.stopWords.contains(lowercased) {
                break
            }

            // Skip empty words
            if word.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
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
    /// For example: "The-Matrix-1999" -> "The Matrix 1999" but "Spider-Man" -> "Spider-Man"
    private func replaceHyphenSeparators(in text: String) -> String {
        // If text contains spaces, preserve all hyphens (they're part of compound words)
        if text.contains(" ") {
            return text
        }

        // No spaces - this is a separator-based filename
        // Count hyphens to determine if they're separators
        let hyphenCount = text.filter { $0 == "-" }.count

        // If there are 3+ hyphens, it's almost certainly a separator-based filename
        if hyphenCount >= 3 {
            return text.replacingOccurrences(of: "-", with: " ")
        }

        // For 1-2 hyphens, check if they're between Title-Case words
        // "Spider-Man" has 1 hyphen, "X-Men-Apocalypse" has 2
        // "The-Matrix" has 1 hyphen but follows different pattern

        var result = ""
        let chars = Array(text)

        for i in 0..<chars.count {
            let char = chars[i]
            if char == "-" {
                // Get the word before and after this hyphen
                let prevWord = extractWordBefore(chars: chars, index: i)
                let nextWord = extractWordAfter(chars: chars, index: i)

                // Preserve hyphen if:
                // 1. Both words are short (likely a compound like "Spider-Man", "X-Men")
                // 2. Or next word starts with capital and prev ends with lowercase
                //    (like "Spider-Man" but not "The-Matrix" in a separator context)
                let isLikelyCompound = isCompoundWord(prev: prevWord, next: nextWord)

                if isLikelyCompound {
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

    /// Extract the word before the given index
    private func extractWordBefore(chars: [Character], index: Int) -> String {
        var word = ""
        var i = index - 1
        while i >= 0 && (chars[i].isLetter || chars[i].isNumber) {
            word = String(chars[i]) + word
            i -= 1
        }
        return word
    }

    /// Extract the word after the given index
    private func extractWordAfter(chars: [Character], index: Int) -> String {
        var word = ""
        var i = index + 1
        while i < chars.count && (chars[i].isLetter || chars[i].isNumber) {
            word += String(chars[i])
            i += 1
        }
        return word
    }

    /// Determine if two words form a compound word like "Spider-Man" vs separate words like "The-Matrix"
    private func isCompoundWord(prev: String, next: String) -> Bool {
        guard !prev.isEmpty, !next.isEmpty else { return false }

        // Known compound word patterns
        let compoundPrefixes = ["spider", "bat", "super", "iron", "ant", "x"]
        let compoundSuffixes = ["man", "men", "woman", "women", "girl", "boy"]

        let prevLower = prev.lowercased()
        let nextLower = next.lowercased()

        // Check if this matches a known compound pattern
        if compoundPrefixes.contains(prevLower) && compoundSuffixes.contains(nextLower) {
            return true
        }

        // Single letter prefix like "X-Men", "T-Rex"
        if prev.count == 1 && prev.first?.isUppercase == true {
            return true
        }

        return false
    }

    /// Check if a year is in a reasonable range for movies
    private func isValidYear(_ year: Int) -> Bool {
        year >= 1888 && year <= Calendar.current.component(.year, from: Date()) + 5
    }
}
