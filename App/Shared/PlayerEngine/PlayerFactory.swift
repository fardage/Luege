import Foundation
import LuegeCore

/// Factory for creating the VLC player engine
public enum PlayerFactory {
    /// Create a player engine for the given file
    /// - Parameter file: The file entry to play
    /// - Returns: A configured VLC player engine instance
    @MainActor
    public static func createEngine(for file: FileEntry) -> any PlayerEngine {
        return VLCPlayerEngine()
    }

    /// Create a player engine
    /// - Returns: A configured VLC player engine instance
    @MainActor
    public static func createEngine() -> any PlayerEngine {
        return VLCPlayerEngine()
    }

    /// Check if VLCKit is available on this platform
    /// Always returns true since VLCKit is always available in the App layer
    public static var isVLCAvailable: Bool {
        return true
    }
}
