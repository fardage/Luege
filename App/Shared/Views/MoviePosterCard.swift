import SwiftUI

/// A movie poster card for display in grid views
struct MoviePosterCard: View {
    let metadata: MovieMetadata
    let onTap: () -> Void

    @EnvironmentObject private var metadataService: MetadataService

    private let posterAspectRatio: CGFloat = 2 / 3

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                posterImage
                    .aspectRatio(posterAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(metadata.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(metadata.year.map(String.init) ?? " ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .buttonStyle(.card)
        #endif
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
            Color.gray.opacity(0.2)

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

#Preview {
    let metadata = MovieMetadata(
        id: UUID(),
        tmdbId: 603,
        title: "The Matrix",
        year: 1999,
        genres: ["Action", "Sci-Fi"],
        posterPath: "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg"
    )

    return MoviePosterCard(metadata: metadata) {
        print("Tapped")
    }
    .frame(width: 150)
    .environmentObject(MetadataService())
}
