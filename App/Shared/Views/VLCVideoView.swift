import SwiftUI

#if canImport(MobileVLCKit)
import MobileVLCKit
#elseif canImport(TVVLCKit)
import TVVLCKit
#endif

#if canImport(MobileVLCKit) || canImport(TVVLCKit)

/// SwiftUI wrapper for VLC video rendering
struct VLCVideoView: UIViewRepresentable {
    let mediaPlayer: VLCMediaPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false  // Allow taps to pass through to SwiftUI
        mediaPlayer.drawable = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensure drawable is still set
        if mediaPlayer.drawable as? UIView !== uiView {
            mediaPlayer.drawable = uiView
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Clean up if needed
    }
}

#else

/// Placeholder when VLCKit is not available
struct VLCVideoView: View {
    var body: some View {
        Color.black
            .overlay {
                Text("VLC not available")
                    .foregroundStyle(.secondary)
            }
    }
}

#endif
