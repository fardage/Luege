import SwiftUI

/// A horizontal scrolling row showing in-progress media items for quick resume (tvOS)
struct ContinueWatchingRow: View {
    let onPlay: (LibraryFile, LibraryFolder, SavedShare, TimeInterval) -> Void

    @EnvironmentObject private var progressService: PlaybackProgressService
    @EnvironmentObject private var libraryService: LibraryService
    @EnvironmentObject private var metadataService: MetadataService
    @EnvironmentObject private var shareManager: ShareManager

    var body: some View {
        // Reference progressVersion to track changes
        let _ = progressService.progressVersion

        let items = progressService.resumableItems()

        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Continue Watching")
                    .font(.headline)
                    .padding(.leading, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        ForEach(items, id: \.fileId) { progress in
                            if let file = libraryService.file(for: progress.fileId) {
                                ContinueWatchingCard(
                                    progress: progress,
                                    file: file,
                                    onTap: {
                                        handleTap(progress: progress, file: file)
                                    },
                                    onMarkWatched: {
                                        progressService.markAsWatched(fileId: progress.fileId)
                                    },
                                    onRemove: {
                                        progressService.deleteProgress(for: progress.fileId)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.leading, 4)
                    .padding(.vertical, 20)
                }
            }
        }
    }

    private func handleTap(progress: PlaybackProgress, file: LibraryFile) {
        guard let folder = libraryService.folder(for: file.id),
              let share = shareManager.savedShare(for: folder.shareId) else {
            return
        }
        onPlay(file, folder, share, progress.currentTime)
    }
}

// MARK: - Continue Watching Card

private struct ContinueWatchingCard: View {
    let progress: PlaybackProgress
    let file: LibraryFile
    let onTap: () -> Void
    let onMarkWatched: () -> Void
    let onRemove: () -> Void

    @EnvironmentObject private var metadataService: MetadataService

    private let posterAspectRatio: CGFloat = 2 / 3

    var body: some View {
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
        .containerRelativeFrame(.horizontal, count: 7, spacing: 40)
        .contextMenu {
            contextMenuItems
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onMarkWatched()
        } label: {
            Label("Mark as Watched", systemImage: "checkmark.circle")
        }

        Button(role: .destructive) {
            onRemove()
        } label: {
            Label("Remove from Continue Watching", systemImage: "xmark.circle")
        }
    }

    // MARK: - Computed Properties

    private var textLabels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayTitle)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(remainingTimeText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var displayTitle: String {
        if let metadata = metadataService.cachedMetadata(for: file) {
            return metadata.title
        }
        if let episode = metadataService.cachedTVEpisodeMetadata(for: file) {
            return episode.name
        }
        // Fall back to filename without extension
        let name = file.fileName
        if let dotIndex = name.lastIndex(of: ".") {
            return String(name[name.startIndex..<dotIndex])
        }
        return name
    }

    private var remainingTimeText: String {
        let remaining = progress.duration - progress.currentTime
        guard remaining > 0 else { return "" }
        let totalSeconds = Int(remaining)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }

    private var posterPath: String? {
        if let metadata = metadataService.cachedMetadata(for: file) {
            return metadata.posterPath
        }
        if let episode = metadataService.cachedTVEpisodeMetadata(for: file),
           let show = metadataService.cachedTVShowMetadata(forTmdbId: episode.seriesTmdbId) {
            return show.posterPath
        }
        return nil
    }

    // MARK: - Views

    @ViewBuilder
    private var posterImage: some View {
        CachedAsyncImage(
            fileId: file.id,
            posterPath: posterPath,
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
                Image(systemName: "play.rectangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text(displayTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
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
