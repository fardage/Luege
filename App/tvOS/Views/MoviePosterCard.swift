import SwiftUI

/// A movie poster card for display in grid views (tvOS)
struct MoviePosterCard: View {
    let metadata: MovieMetadata
    let onTap: () -> Void

    @EnvironmentObject private var metadataService: MetadataService
    @EnvironmentObject private var progressService: PlaybackProgressService

    private let posterAspectRatio: CGFloat = 2 / 3

    var body: some View {
        // Reference progressVersion to track changes
        let _ = progressService.progressVersion

        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                posterImage
                    .aspectRatio(posterAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottom) {
                        progressBar
                    }
            }
            .buttonStyle(PosterButtonStyle())

            textLabels
        }
    }

    // MARK: - Text Labels

    private var textLabels: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(metadata.year.map(String.init) ?? " ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if progressService.isWatched(metadata.id) {
                Spacer(minLength: 0)

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 22))
            }
        }
    }

    // MARK: - Progress Bar

    @ViewBuilder
    private var progressBar: some View {
        if let progress = progressService.progress(for: metadata.id),
           !progress.isWatched && progress.progress > 0.01 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * progress.progress)
                }
            }
            .frame(height: 3)
            .clipShape(RoundedRectangle(cornerRadius: 1.5))
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var posterImage: some View {
        CachedAsyncImage(
            fileId: metadata.id,
            posterPath: metadata.posterPath,
            size: .grid
        ) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            placeholderView
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        ZStack {
            Color.white.opacity(0.08)

            VStack(spacing: 8) {
                Image(systemName: "film")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text(metadata.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }
}
