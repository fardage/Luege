import AVFoundation
import SwiftUI

#if os(iOS) || os(tvOS)
import UIKit

/// UIKit wrapper for AVPlayerLayer to integrate with SwiftUI
struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.player = player
    }
}

/// Custom UIView that hosts an AVPlayerLayer
final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspect
        }
    }
}

#elseif os(macOS)
import AppKit

/// AppKit wrapper for AVPlayerLayer to integrate with SwiftUI
struct VideoPlayerLayer: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerLayerView, context: Context) {
        nsView.player = player
    }
}

/// Custom NSView that hosts an AVPlayerLayer
final class PlayerLayerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    private var playerLayer: AVPlayerLayer? {
        layer as? AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer?.player }
        set {
            if layer == nil || !(layer is AVPlayerLayer) {
                layer = AVPlayerLayer()
            }
            playerLayer?.player = newValue
            playerLayer?.videoGravity = .resizeAspect
        }
    }

    override func makeBackingLayer() -> CALayer {
        AVPlayerLayer()
    }
}
#endif
