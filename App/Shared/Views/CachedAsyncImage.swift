import SwiftUI

/// An AsyncImage that supports loading from disk cache first
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let fileId: UUID
    private let posterPath: String?
    private let size: PosterSize
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @EnvironmentObject private var metadataService: MetadataService
    @State private var cachedImage: Image?
    @State private var isLoading = false

    init(
        fileId: UUID,
        posterPath: String?,
        size: PosterSize = .grid,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.fileId = fileId
        self.posterPath = posterPath
        self.size = size
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                content(cachedImage)
            } else if let localURL = metadataService.posterURL(for: fileId, size: size) {
                // Load from disk cache
                AsyncImage(url: localURL) { phase in
                    switch phase {
                    case .success(let image):
                        content(image)
                    case .failure:
                        placeholder()
                    case .empty:
                        placeholder()
                    @unknown default:
                        placeholder()
                    }
                }
            } else if let posterPath = posterPath {
                // Fall back to remote URL
                if let url = TMDbService.posterURL(path: posterPath, size: tmdbSize) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            content(image)
                        case .failure:
                            placeholder()
                        case .empty:
                            ProgressView()
                        @unknown default:
                            placeholder()
                        }
                    }
                } else {
                    placeholder()
                }
            } else {
                placeholder()
            }
        }
    }

    private var tmdbSize: TMDbService.PosterSize {
        switch size {
        case .w92: return .w92
        case .w154: return .w154
        case .w185: return .w185
        case .w342: return .w342
        case .w500: return .w500
        case .w780: return .w780
        case .original: return .original
        }
    }
}

// MARK: - Convenience Initializer

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(fileId: UUID, posterPath: String?, size: PosterSize = .grid) {
        self.init(
            fileId: fileId,
            posterPath: posterPath,
            size: size,
            content: { $0 },
            placeholder: { Color.gray.opacity(0.3) }
        )
    }
}
