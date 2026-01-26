import SwiftUI
import LuegeCore

struct SavedShareRow: View {
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
        .contentShape(Rectangle())
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
