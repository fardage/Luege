import SwiftUI

struct FileEntryRow: View {
    let entry: FileEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.body)
                        .lineLimit(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if entry.isFolder {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(entry.isFolder ? "Double-tap to open folder" : "")
    }

    private var iconName: String {
        switch entry.type {
        case .folder:
            return "folder.fill"
        case .file:
            if entry.isVideoFile {
                return "film"
            }
            return "doc"
        case .symlink:
            return "link"
        case .unknown:
            return "questionmark.square"
        }
    }

    private var iconColor: Color {
        switch entry.type {
        case .folder:
            return .blue
        case .file:
            if entry.isVideoFile {
                return .orange
            }
            return .secondary
        case .symlink:
            return .purple
        case .unknown:
            return .secondary
        }
    }

    private var subtitle: String? {
        if entry.isFolder {
            return nil
        }

        var parts: [String] = []

        if !entry.fileExtension.isEmpty {
            parts.append(entry.fileExtension.uppercased())
        }

        if let size = entry.formattedSize {
            parts.append(size)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    private var accessibilityLabel: String {
        var label = entry.name

        if entry.isFolder {
            label += ", folder"
        } else if entry.isVideoFile {
            label += ", video"
            if let size = entry.formattedSize {
                label += ", \(size)"
            }
        } else {
            label += ", file"
        }

        return label
    }
}
