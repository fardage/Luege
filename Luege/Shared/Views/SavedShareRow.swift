import SwiftUI
import LuegeCore

/// Content view for a saved share row (used inside NavigationLink)
struct SavedShareRowContent: View {
    let share: SavedShare
    let status: ConnectionStatus
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(share.displayName)
                    .font(.headline)

                Text("smb://\(share.hostAddress)/\(share.shareName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ConnectionStatusBadge(status: status)
        }
        #if os(iOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        #else
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        #endif
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(share.displayName), \(status.displayText)")
    }
}

/// Standalone saved share row (for use without NavigationLink)
struct SavedShareRow: View {
    let share: SavedShare
    let status: ConnectionStatus
    let onDelete: () -> Void

    var body: some View {
        SavedShareRowContent(share: share, status: status, onDelete: onDelete)
            .contentShape(Rectangle())
    }
}
