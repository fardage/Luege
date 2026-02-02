import SwiftUI

/// Cinematic movie detail header with backdrop, gradient, and overlaid title
private struct MovieDetailHeaderView: View {
    let metadata: MovieMetadata

    #if os(iOS)
    private let backdropHeight: CGFloat = 300
    private let backdropSize: TMDbService.BackdropSize = .w780
    #elseif os(tvOS)
    private let backdropHeight: CGFloat = 500
    private let backdropSize: TMDbService.BackdropSize = .w1280
    #endif

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Backdrop image
                backdropImage
                    .frame(width: geometry.size.width, height: backdropHeight)

                // Gradient overlay
                gradientOverlay

                // Title and metadata overlay
                titleOverlay
            }
        }
        .frame(height: backdropHeight)
    }

    // MARK: - Backdrop Image

    @ViewBuilder
    private var backdropImage: some View {
        if let backdropPath = metadata.backdropPath,
           let url = TMDbService.backdropURL(path: backdropPath, size: backdropSize) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .empty:
                    backdropPlaceholder
                        .overlay {
                            ProgressView()
                        }
                case .failure:
                    backdropPlaceholder
                @unknown default:
                    backdropPlaceholder
                }
            }
        } else {
            backdropPlaceholder
        }
    }

    @ViewBuilder
    private var backdropPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - Gradient Overlay

    private var gradientOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.4),
                .init(color: backgroundColor.opacity(0.8), location: 0.75),
                .init(color: backgroundColor, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var backgroundColor: Color {
        #if os(iOS)
        Color(.systemBackground)
        #elseif os(tvOS)
        Color.black
        #endif
    }

    // MARK: - Title Overlay

    @ViewBuilder
    private var titleOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metadata.title)
                .font(.title.bold())
                .foregroundStyle(.primary)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)

            metadataRow
        }
        #if os(iOS)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        #elseif os(tvOS)
        .padding(.horizontal, 80)
        .padding(.bottom, 24)
        #endif
    }

    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: 12) {
            if let runtime = metadata.formattedRuntime {
                Text(runtime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if metadata.formattedRuntime != nil && metadata.year != nil {
                Text("•")
                    .foregroundStyle(.secondary)
            }

            if let year = metadata.year {
                Text(String(year))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if (metadata.formattedRuntime != nil || metadata.year != nil),
               let rating = metadata.voteAverage, rating > 0 {
                Text("•")
                    .foregroundStyle(.secondary)
            }

            if let rating = metadata.voteAverage, rating > 0 {
                ratingBadge(rating: rating)
            }
        }
    }

    @ViewBuilder
    private func ratingBadge(rating: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            Text(String(format: "%.1f", rating))
                .font(.subheadline.weight(.medium))
        }
    }
}

/// Detailed movie view shown as a sheet with cinematic Infuse-style header
struct MovieDetailView: View {
    let metadata: MovieMetadata
    let file: LibraryFile
    let onPlay: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var metadataService: MetadataService

    #if os(iOS)
    private let contentPadding: CGFloat = 20
    #elseif os(tvOS)
    private let contentPadding: CGFloat = 80
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Cinematic header with backdrop
                    MovieDetailHeaderView(metadata: metadata)

                    // Content section
                    VStack(alignment: .leading, spacing: 24) {
                        genresSection
                        playButton
                        synopsisSection
                    }
                    .padding(.horizontal, contentPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
            }
            #elseif os(tvOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Close") { onDismiss() }
                }
            }
            #endif
        }
    }

    // MARK: - Genres Section

    @ViewBuilder
    private var genresSection: some View {
        if !metadata.genres.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(metadata.genres, id: \.self) { genre in
                        Text(genre)
                            #if os(iOS)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            #elseif os(tvOS)
                            .font(.callout)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            #endif
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Play Button

    @ViewBuilder
    private var playButton: some View {
        Button(action: onPlay) {
            Label("Play", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                #if os(iOS)
                .padding(.vertical, 14)
                #elseif os(tvOS)
                .padding(.vertical, 20)
                #endif
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Synopsis Section

    @ViewBuilder
    private var synopsisSection: some View {
        if let synopsis = metadata.synopsis, !synopsis.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Synopsis")
                    .font(.headline)

                Text(synopsis)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let metadata = MovieMetadata(
        id: UUID(),
        tmdbId: 603,
        title: "The Matrix",
        originalTitle: "The Matrix",
        year: 1999,
        runtime: 136,
        genres: ["Action", "Science Fiction", "Thriller"],
        synopsis: "A computer hacker learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.",
        posterPath: "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
        backdropPath: "/fNG7i7RqMErkcqhohV2a6cV1Ehy.jpg",
        voteAverage: 8.2
    )

    let file = LibraryFile(
        id: metadata.id,
        folderId: UUID(),
        relativePath: "The Matrix (1999).mkv",
        fileName: "The Matrix (1999).mkv",
        size: 5_000_000_000,
        modifiedDate: nil
    )

    return MovieDetailView(
        metadata: metadata,
        file: file,
        onPlay: { print("Play") },
        onDismiss: { print("Dismiss") }
    )
    .environmentObject(MetadataService())
}
