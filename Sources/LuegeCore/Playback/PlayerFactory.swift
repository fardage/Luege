import Foundation

/// Factory for creating the appropriate player engine based on media format
public enum PlayerFactory {
    /// Determine which player engine type to use for a given format
    /// - Parameter format: The media format to analyze
    /// - Returns: The recommended player engine type
    public static func engineType(for format: MediaFormat) -> PlayerEngineType {
        if format.canUseNativePlayer {
            return .avPlayer
        } else {
            return .vlc
        }
    }

    /// Determine which player engine type to use for a file
    /// - Parameter file: The file entry to analyze
    /// - Returns: The recommended player engine type
    public static func engineType(for file: FileEntry) -> PlayerEngineType {
        let analyzer = FormatAnalyzer()
        let format = analyzer.analyze(file: file)
        return engineType(for: format)
    }

    /// Determine which player engine type to use based on file path
    /// - Parameter path: Path to the media file
    /// - Returns: The recommended player engine type
    public static func engineType(forPath path: String) -> PlayerEngineType {
        let analyzer = FormatAnalyzer()
        let format = analyzer.analyze(path: path)
        return engineType(for: format)
    }

    /// Create a player engine for the given format
    /// - Parameters:
    ///   - format: The media format
    ///   - fileReader: Optional custom file reader for AVPlayerEngine
    /// - Returns: A configured player engine instance
    @MainActor
    public static func createEngine(
        for format: MediaFormat,
        fileReader: (any SMBFileReading)? = nil
    ) -> any PlayerEngine {
        let type = engineType(for: format)
        return createEngine(ofType: type, fileReader: fileReader)
    }

    /// Create a player engine for the given file
    /// - Parameters:
    ///   - file: The file entry to play
    ///   - fileReader: Optional custom file reader for AVPlayerEngine
    /// - Returns: A configured player engine instance
    @MainActor
    public static func createEngine(
        for file: FileEntry,
        fileReader: (any SMBFileReading)? = nil
    ) -> any PlayerEngine {
        let type = engineType(for: file)
        return createEngine(ofType: type, fileReader: fileReader)
    }

    /// Create a player engine of a specific type
    /// - Parameters:
    ///   - type: The engine type to create
    ///   - fileReader: Optional custom file reader for AVPlayerEngine
    /// - Returns: A configured player engine instance
    @MainActor
    public static func createEngine(
        ofType type: PlayerEngineType,
        fileReader: (any SMBFileReading)? = nil
    ) -> any PlayerEngine {
        switch type {
        case .avPlayer:
            if let reader = fileReader {
                return AVPlayerEngine(fileReader: reader)
            }
            return AVPlayerEngine()
        case .vlc:
            return VLCPlayerEngine()
        }
    }

    /// Check if VLCKit is available on this platform
    public static var isVLCAvailable: Bool {
        #if canImport(MobileVLCKit) || canImport(TVVLCKit)
        return true
        #else
        return false
        #endif
    }
}
