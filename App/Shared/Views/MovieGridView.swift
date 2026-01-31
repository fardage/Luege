import SwiftUI

/// Grid view for displaying movie posters
struct MovieGridView: View {
    let files: [LibraryFile]
    let onSelect: (LibraryFile, MovieMetadata?) -> Void

    @EnvironmentObject private var metadataService: MetadataService

    #if os(tvOS)
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 40)
    ]
    #else
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 16)
    ]
    #endif

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(files) { file in
                    movieCard(for: file)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func movieCard(for file: LibraryFile) -> some View {
        let metadata = metadataService.cachedMetadata(for: file)

        if let metadata = metadata, metadata.isMatched {
            MoviePosterCard(metadata: metadata) {
                onSelect(file, metadata)
            }
        } else {
            // Show placeholder card for unmatched files
            unMatchedCard(for: file, metadata: metadata)
        }
    }

    @ViewBuilder
    private func unMatchedCard(for file: LibraryFile, metadata: MovieMetadata?) -> some View {
        let parser = FilenameParser()
        let parseResult = parser.parse(file.fileName)
        let displayMetadata = metadata ?? MovieMetadata.unmatched(
            fileId: file.id,
            parseResult: parseResult
        )

        MoviePosterCard(metadata: displayMetadata) {
            onSelect(file, metadata)
        }
    }
}

#Preview {
    let files = [
        LibraryFile(
            id: UUID(),
            folderId: UUID(),
            relativePath: "The Matrix (1999).mkv",
            fileName: "The Matrix (1999).mkv",
            size: 5_000_000_000,
            modifiedDate: nil
        ),
        LibraryFile(
            id: UUID(),
            folderId: UUID(),
            relativePath: "Inception (2010).mkv",
            fileName: "Inception (2010).mkv",
            size: 4_000_000_000,
            modifiedDate: nil
        )
    ]

    return MovieGridView(files: files) { file, metadata in
        print("Selected: \(file.fileName)")
    }
    .environmentObject(MetadataService())
}
