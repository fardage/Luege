import LuegeCore
import SwiftUI

/// Error view displayed when video playback fails
struct VideoErrorView: View {
    let error: PlaybackError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    private var isUnsupportedMedia: Bool {
        error.isUnsupportedMedia
    }

    private var errorIcon: String {
        if isUnsupportedMedia {
            return "film.slash"
        }
        return "exclamationmark.triangle.fill"
    }

    private var errorTitle: String {
        switch error {
        case .unsupportedFormat:
            return "Format Not Supported"
        case .unsupportedVideoCodec:
            return "Video Codec Not Supported"
        case .unsupportedAudioCodec:
            return "Audio Codec Not Supported"
        case .vlcNotAvailable:
            return "Player Not Available"
        case .vlcError:
            return "VLC Playback Error"
        default:
            return "Playback Error"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: errorIcon)
                .font(.system(size: 56))
                .foregroundStyle(isUnsupportedMedia ? Color.secondary : Color.orange)

            Text(errorTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 16) {
                // Only show retry for recoverable errors
                if !isUnsupportedMedia {
                    Button {
                        onRetry()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }

                Button {
                    onDismiss()
                } label: {
                    Label("Close", systemImage: "xmark")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
        }
        .padding(40)
        .background(.ultraThinMaterial.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
