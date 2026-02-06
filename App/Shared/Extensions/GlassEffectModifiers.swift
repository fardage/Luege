import SwiftUI

// MARK: - Adaptive Glass Button Styles

/// A play button that uses `.glassProminent` on iOS/tvOS 26+ with a white capsule fallback.
struct AdaptiveGlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, tvOS 26, *) {
            configuration.label
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            configuration.label
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(configuration.isPressed ? 0.15 : 0.25))
                .clipShape(Capsule())
        }
    }
}

/// A secondary capsule button that uses glass effect on iOS/tvOS 26+ with a translucent fallback.
struct AdaptiveGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, tvOS 26, *) {
            configuration.label
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            configuration.label
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.12))
                .clipShape(Capsule())
        }
    }
}

/// A secondary circle button that uses glass effect on iOS/tvOS 26+ with a translucent fallback.
struct AdaptiveGlassCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, tvOS 26, *) {
            configuration.label
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            configuration.label
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(configuration.isPressed ? 0.1 : 0.15))
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
