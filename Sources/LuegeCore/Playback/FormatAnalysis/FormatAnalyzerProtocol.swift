import Foundation

/// Protocol for analyzing media file formats
public protocol FormatAnalyzing: Sendable {
    /// Analyze the format of a file based on its path
    /// - Parameter path: Path to the media file
    /// - Returns: The detected media format
    func analyze(path: String) -> MediaFormat

    /// Analyze the format of a file entry
    /// - Parameter file: The file entry to analyze
    /// - Returns: The detected media format
    func analyze(file: FileEntry) -> MediaFormat
}
