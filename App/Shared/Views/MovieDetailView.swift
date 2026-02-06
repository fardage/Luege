import SwiftUI

/// Cinematic backdrop header — full-bleed image with gradient fading to black
private struct MovieDetailHeaderView: View {
    let metadata: MovieMetadata

    #if os(iOS)
    private let backdropSize: TMDbService.BackdropSize = .w1280
    private var backdropHeight: CGFloat { UIScreen.main.bounds.height * 0.55 }
    #elseif os(tvOS)
    private let backdropSize: TMDbService.BackdropSize = .w1280
    private var backdropHeight: CGFloat { UIScreen.main.bounds.height * 0.58 }
    #endif

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                backdropImage
                    .frame(width: geometry.size.width, height: backdropHeight)
                    .clipped()

                gradientOverlay
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
                        .overlay { ProgressView() }
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
                .init(color: .clear, location: 0.45),
                .init(color: .black.opacity(0.7), location: 0.75),
                .init(color: .black, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Apple TV app–style movie detail view with centered layout and dark cinematic theme
struct MovieDetailView: View {
    let metadata: MovieMetadata
    let file: LibraryFile
    let onPlay: (TimeInterval?) -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var metadataService: MetadataService
    @EnvironmentObject private var progressService: PlaybackProgressService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Cinematic backdrop
                    MovieDetailHeaderView(metadata: metadata)

                    // Centered content below backdrop
                    VStack(spacing: 16) {
                        titleSection
                        genreLine
                        watchedLabel
                        buttonRow
                        synopsisSection
                        metadataInfoRow
                    }
                    #if os(iOS)
                    .padding(.horizontal, 20)
                    #elseif os(tvOS)
                    .padding(.horizontal, 80)
                    #endif
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color.black)
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

    // MARK: - Title

    private var titleSection: some View {
        Text(metadata.title)
            #if os(iOS)
            .font(.title.bold())
            #elseif os(tvOS)
            .font(.largeTitle.bold())
            #endif
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Genre Line (dot-separated)

    @ViewBuilder
    private var genreLine: some View {
        let parts = ["Movie"] + metadata.genres
        if !metadata.genres.isEmpty {
            Text(parts.joined(separator: " \u{00B7} "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Watched Label

    @ViewBuilder
    private var watchedLabel: some View {
        if progressService.isWatched(file.id) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Watched")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Button Row

    private var fileProgress: PlaybackProgress? {
        progressService.progress(for: file.id)
    }

    private var buttonRow: some View {
        HStack(spacing: 16) {
            if let progress = fileProgress, progress.isResumable {
                Button { onPlay(progress.currentTime) } label: {
                    Label("Resume from \(progress.formattedResumeTime)", systemImage: "play.fill")
                        .font(.headline)
                }
                .buttonStyle(.adaptiveGlassProminent)

                Button { onPlay(nil) } label: {
                    Label("Start from Beginning", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.adaptiveGlass)
            } else {
                Button { onPlay(nil) } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                }
                .buttonStyle(.adaptiveGlassProminent)
            }

            Menu {
                if progressService.isWatched(file.id) {
                    Button {
                        progressService.markAsUnwatched(fileId: file.id)
                    } label: {
                        Label("Mark as Unwatched", systemImage: "eye.slash")
                    }
                } else {
                    Button {
                        progressService.markAsWatched(fileId: file.id)
                    } label: {
                        Label("Mark as Watched", systemImage: "eye")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Synopsis

    @ViewBuilder
    private var synopsisSection: some View {
        if let synopsis = metadata.synopsis, !synopsis.isEmpty {
            ExpandableText(text: synopsis, lineLimit: 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
    }

    // MARK: - Metadata Info Row (Year · Runtime · Rating)

    @ViewBuilder
    private var metadataInfoRow: some View {
        let parts = metadataComponents
        if !parts.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    if index > 0 {
                        Text("\u{00B7}")
                            .foregroundStyle(.secondary)
                    }
                    part
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private var metadataComponents: [AnyView] {
        var components: [AnyView] = []

        if let year = metadata.year {
            components.append(AnyView(Text(String(year))))
        }

        if let runtime = metadata.formattedRuntime {
            components.append(AnyView(Text(runtime)))
        }

        if let rating = metadata.voteAverage, rating > 0 {
            components.append(AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                }
            ))
        }

        return components
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
        onPlay: { startTime in print("Play from \(String(describing: startTime))") },
        onDismiss: { print("Dismiss") }
    )
    .environmentObject(MetadataService())
    .environmentObject(PlaybackProgressService())
}
