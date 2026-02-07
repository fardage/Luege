import SwiftUI

/// A custom button style for poster image buttons on tvOS.
/// Provides a scale-up + shadow effect on focus without the system's default focus platter.
struct PosterButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: .black.opacity(isFocused ? 0.3 : 0), radius: 10, y: 5)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
