import SwiftUI

/// Detailed movie view shown as a sheet
struct MovieDetailView: View {
    let metadata: MovieMetadata
    let file: LibraryFile
    let onPlay: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var metadataService: MetadataService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    infoSection
                    synopsisSection
                }
                .padding()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onPlay) {
                        Label("Play", systemImage: "play.fill")
                    }
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

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 20) {
            // Poster
            CachedAsyncImage(
                fileId: metadata.id,
                posterPath: metadata.posterPath,
                size: .detail
            ) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(2/3, contentMode: .fit)
                    .overlay {
                        Image(systemName: "film")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }
            #if os(iOS)
            .frame(width: 150)
            #elseif os(tvOS)
            .frame(width: 300)
            #endif

            // Title and metadata
            VStack(alignment: .leading, spacing: 12) {
                Text(metadata.title)
                    .font(.title.bold())

                if let year = metadata.year {
                    Text(String(year))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                if let rating = metadata.voteAverage, rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.headline)
                    }
                }

                #if os(tvOS)
                Spacer()

                Button(action: onPlay) {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                #endif
            }

            Spacer()
        }
    }

    // MARK: - Info Section

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let runtime = metadata.formattedRuntime {
                infoRow(label: "Runtime", value: runtime)
            }

            if let genres = metadata.formattedGenres {
                infoRow(label: "Genres", value: genres)
            }

            if let originalTitle = metadata.originalTitle, originalTitle != metadata.title {
                infoRow(label: "Original Title", value: originalTitle)
            }
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.subheadline)
        }
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
        genres: ["Action", "Science Fiction"],
        synopsis: "A computer hacker learns from mysterious rebels about the true nature of his reality and his role in the war against its controllers.",
        posterPath: "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
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
