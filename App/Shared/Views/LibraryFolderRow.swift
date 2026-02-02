import SwiftUI

struct LibraryFolderRow: View {
    let folder: LibraryFolder
    let shareName: String?
    let status: ConnectionStatus
    let onTap: () -> Void
    let onRemove: () -> Void
    let onRescan: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: rowSpacing) {
                Image(systemName: folder.contentType.iconName)
                    .font(iconFont)
                    .foregroundStyle(status.isOnline ? .primary : .secondary)
                    .frame(width: iconWidth)

                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.displayName)
                        .font(titleFont)
                        .foregroundStyle(status.isOnline ? .primary : .secondary)

                    HStack(spacing: 8) {
                        if let shareName = shareName {
                            Text(shareName)
                                .font(subtitleFont)
                                .foregroundStyle(.secondary)
                        }

                        if let videoCount = folder.videoCount {
                            Text("\(videoCount) video\(videoCount == 1 ? "" : "s")")
                                .font(subtitleFont)
                                .foregroundStyle(.secondary)
                        }

                        if folder.scanError != nil {
                            Image(systemName: "xmark.circle.fill")
                                .font(subtitleFont)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Spacer()

                if !status.isOnline {
                    ConnectionStatusBadge(status: status)
                }
            }
            #if os(tvOS)
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            #endif
            .contentShape(Rectangle())
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
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

    // MARK: - Platform-specific styling

    private var rowSpacing: CGFloat {
        #if os(tvOS)
        return 24
        #else
        return 12
        #endif
    }

    private var iconWidth: CGFloat {
        #if os(tvOS)
        return 48
        #else
        return 32
        #endif
    }

    private var iconFont: Font {
        #if os(tvOS)
        return .title
        #else
        return .title2
        #endif
    }

    private var titleFont: Font {
        #if os(tvOS)
        return .title3
        #else
        return .headline
        #endif
    }

    private var subtitleFont: Font {
        #if os(tvOS)
        return .callout
        #else
        return .caption
        #endif
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
            onTap: {},
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
            onTap: {},
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
            onTap: {},
            onRemove: {},
            onRescan: {}
        )
    }
}
