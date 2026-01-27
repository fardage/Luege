import LuegeCore
import SwiftUI

/// Error view displayed when video playback fails
struct VideoErrorView: View {
    let error: PlaybackError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    private var isUnsupportedFormat: Bool {
        if case .unsupportedFormat = error {
            return true
        }
        return false
    }

    private var errorIcon: String {
        if isUnsupportedFormat {
            return "film.slash"
        }
        return "exclamationmark.triangle.fill"
    }

    private var errorTitle: String {
        if isUnsupportedFormat {
            return "Format Not Supported"
        }
        return "Playback Error"
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: errorIcon)
                .font(.system(size: 56))
                .foregroundStyle(isUnsupportedFormat ? Color.secondary : Color.orange)

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
                if !isUnsupportedFormat {
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
