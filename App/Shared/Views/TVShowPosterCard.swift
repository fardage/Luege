import SwiftUI

/// A TV show poster card for display in grid views
struct TVShowPosterCard: View {
    let show: TVShowMetadata
    let episodeCount: Int
    let onTap: () -> Void

    @EnvironmentObject private var metadataService: MetadataService

    private let posterAspectRatio: CGFloat = 2 / 3

    var body: some View {
        #if os(tvOS)
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                posterImage
                    .aspectRatio(posterAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PosterButtonStyle())

            textLabels
        }
        #else
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                posterImage
                    .aspectRatio(posterAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                textLabels
            }
        }
        .buttonStyle(.plain)
        #endif
    }

    // MARK: - Text Labels

    private var textLabels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(show.name)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 4) {
                if let year = show.firstAirYear {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if episodeCount > 0 {
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(episodeCount) episodes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var posterImage: some View {
        CachedAsyncImage(
            fileId: show.id,
            posterPath: show.posterPath,
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
                Image(systemName: "tv")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text(show.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }
}

#Preview {
    let show = TVShowMetadata(
        tmdbId: 1399,
        name: "Game of Thrones",
        overview: "Seven noble families fight for control of the mythical land of Westeros.",
        posterPath: "/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg",
        numberOfSeasons: 8,
        numberOfEpisodes: 73,
        genres: ["Drama", "Fantasy"],
        status: "Ended"
    )

    return TVShowPosterCard(show: show, episodeCount: 5) {
        print("Tapped")
    }
    .frame(width: 150)
    .environmentObject(MetadataService())
}
