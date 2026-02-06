import SwiftUI

/// Pairs a library file with its resolved display title for sectioning
private struct MovieItem: Identifiable {
    let file: LibraryFile
    let metadata: MovieMetadata?
    let displayTitle: String
    var id: UUID { file.id }
}

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

    private var movieItems: [MovieItem] {
        let parser = FilenameParser()
        return files.map { file in
            let metadata = metadataService.cachedMetadata(for: file)
            let title: String
            if let metadata, metadata.isMatched {
                title = metadata.title
            } else {
                title = parser.parse(file.fileName).title
            }
            return MovieItem(file: file, metadata: metadata, displayTitle: title)
        }
    }

    private var sections: [AlphabetSection<MovieItem>] {
        alphabeticalSections(from: movieItems, nameKeyPath: \.displayTitle)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        Text(section.letter)
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                            .padding(.horizontal)
                            .id("section_\(section.letter)")

                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(section.items) { item in
                                movieCard(for: item)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            #if !os(tvOS)
            .overlay(alignment: .trailing) {
                AlphabetSectionIndex(
                    activeSections: Set(sections.map(\.letter))
                ) { letter in
                    withAnimation {
                        proxy.scrollTo("section_\(letter)", anchor: .top)
                    }
                }
                .padding(.trailing, 2)
            }
            #endif
        }
    }

    @ViewBuilder
    private func movieCard(for item: MovieItem) -> some View {
        if let metadata = item.metadata, metadata.isMatched {
            MoviePosterCard(metadata: metadata) {
                onSelect(item.file, metadata)
            }
        } else {
            unMatchedCard(for: item.file, metadata: item.metadata)
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
