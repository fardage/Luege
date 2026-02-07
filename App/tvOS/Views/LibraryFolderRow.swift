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
            HStack(spacing: 24) {
                Image(systemName: folder.contentType.iconName)
                    .font(.title)
                    .foregroundStyle(status.isOnline ? .primary : .secondary)
                    .frame(width: 48)
                    .padding(.trailing, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.displayName)
                        .font(.title3)
                        .foregroundStyle(status.isOnline ? .primary : .secondary)

                    HStack(spacing: 8) {
                        if let shareName = shareName {
                            Text(shareName)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                        if let videoCount = folder.videoCount {
                            Text("\(videoCount) video\(videoCount == 1 ? "" : "s")")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                        if folder.scanError != nil {
                            Image(systemName: "xmark.circle.fill")
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Spacer()

                if !status.isOnline {
                    ConnectionStatusBadge(status: status)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.card)
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
