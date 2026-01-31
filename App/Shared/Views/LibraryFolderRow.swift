import SwiftUI

struct LibraryFolderRow: View {
    let folder: LibraryFolder
    let shareName: String?
    let status: ConnectionStatus
    let onRemove: () -> Void
    let onRescan: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: folder.contentType.iconName)
                .font(.title2)
                .foregroundStyle(status.isOnline ? .primary : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.displayName)
                    .font(.headline)
                    .foregroundStyle(status.isOnline ? .primary : .secondary)

                HStack(spacing: 8) {
                    if let shareName = shareName {
                        Text(shareName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let videoCount = folder.videoCount {
                        Text("\(videoCount) video\(videoCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if folder.scanError != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            if !status.isOnline {
                ConnectionStatusBadge(status: status)
            }
        }
        .contentShape(Rectangle())
        #if os(iOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "minus.circle")
            }
        }
        .swipeActions(edge: .leading) {
            Button(action: onRescan) {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .tint(.blue)
        }
        #endif
        .contextMenu {
            Button(action: onRescan) {
                Label("Rescan Folder", systemImage: "arrow.clockwise")
            }
            .disabled(!status.isOnline)

            Button(role: .destructive, action: onRemove) {
                Label("Remove from Library", systemImage: "minus.circle")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var label = folder.displayName
        if let videoCount = folder.videoCount {
            label += ", \(videoCount) video\(videoCount == 1 ? "" : "s")"
        }
        if !status.isOnline {
            label += ", \(status.displayText)"
        }
        return label
    }
}

#Preview {
    List {
        LibraryFolderRow(
            folder: LibraryFolder(
                shareId: UUID(),
                path: "Movies",
                contentType: .movies,
                displayName: "Movies",
                videoCount: 42
            ),
            shareName: "NAS",
            status: .online,
            onRemove: {},
            onRescan: {}
        )

        LibraryFolderRow(
            folder: LibraryFolder(
                shareId: UUID(),
                path: "TV Shows",
                contentType: .tvShows,
                displayName: "TV Shows",
                videoCount: 156
            ),
            shareName: "Media Server",
            status: .offline(reason: "Connection refused"),
            onRemove: {},
            onRescan: {}
        )

        LibraryFolderRow(
            folder: LibraryFolder(
                shareId: UUID(),
                path: "Home Videos",
                contentType: .homeVideos,
                displayName: "Family Videos",
                scanError: "Failed to scan"
            ),
            shareName: "Backup Drive",
            status: .online,
            onRemove: {},
            onRescan: {}
        )
    }
}
