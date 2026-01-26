import SwiftUI
import LuegeCore

struct DiscoveredShareRow: View {
    let share: DiscoveredShare
    let onSave: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(share.displayName)
                    .font(.headline)

                if let comment = share.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("smb://\(share.hostAddress)/\(share.shareName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onSave) {
                Label("Save", systemImage: "plus.circle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Save \(share.displayName)")
        }
        .contentShape(Rectangle())
    }
}
