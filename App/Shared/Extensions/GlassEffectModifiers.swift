import SwiftUI

// MARK: - Adaptive Glass Button Styles

/// A play button that uses `.glassProminent` on iOS/tvOS 26+ with a white capsule fallback.
struct AdaptiveGlassProminentButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, tvOS 26, *) {
            configuration.label
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: .capsule)
                #if os(tvOS)
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                #endif
        } else {
            configuration.label
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                #if os(tvOS)
                .background(Color.white.opacity(isFocused ? 0.35 : 0.25))
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                #else
                .background(Color.white.opacity(configuration.isPressed ? 0.15 : 0.25))
                #endif
                .clipShape(Capsule())
        }
    }
}

/// A secondary capsule button that uses glass effect on iOS/tvOS 26+ with a translucent fallback.
struct AdaptiveGlassButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, tvOS 26, *) {
            configuration.label
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .capsule)
                #if os(tvOS)
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                #endif
        } else {
            configuration.label
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                #if os(tvOS)
                .background(Color.white.opacity(isFocused ? 0.25 : 0.12))
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                #else
                .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.12))
                #endif
                .clipShape(Capsule())
        }
    }
}

/// A secondary circle button that uses glass effect on iOS/tvOS 26+ with a translucent fallback.
struct AdaptiveGlassCircleButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, tvOS 26, *) {
            configuration.label
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
                #if os(tvOS)
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                #endif
        } else {
            configuration.label
                .frame(width: 44, height: 44)
                #if os(tvOS)
                .background(Color.white.opacity(isFocused ? 0.3 : 0.15))
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                #else
                .background(Color.white.opacity(configuration.isPressed ? 0.1 : 0.15))
                #endif
                .clipShape(Circle())
        }
    }
}

extension ButtonStyle where Self == AdaptiveGlassProminentButtonStyle {
    static var adaptiveGlassProminent: AdaptiveGlassProminentButtonStyle {
        AdaptiveGlassProminentButtonStyle()
    }
}

extension ButtonStyle where Self == AdaptiveGlassButtonStyle {
    static var adaptiveGlass: AdaptiveGlassButtonStyle {
        AdaptiveGlassButtonStyle()
    }
}

extension ButtonStyle where Self == AdaptiveGlassCircleButtonStyle {
    static var adaptiveGlassCircle: AdaptiveGlassCircleButtonStyle {
        AdaptiveGlassCircleButtonStyle()
    }
}
