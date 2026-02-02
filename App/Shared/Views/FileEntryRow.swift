import SwiftUI

struct FileEntryRow: View {
    let entry: FileEntry
    let onTap: () -> Void
    var isLibraryFolder: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: rowSpacing) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: iconName)
                        .font(iconFont)
                        .foregroundStyle(iconColor)
                        .frame(width: iconWidth)

                    if isLibraryFolder {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: libraryBadgeSize))
                            .foregroundStyle(.white)
                            .padding(libraryBadgePadding)
                            .background(Color.green)
                            .clipShape(Circle())
                            .offset(x: libraryBadgeOffset, y: libraryBadgeOffset)
                    }
                }
                #if os(tvOS)
                .padding(.trailing, 12)
                #endif

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(titleFont)
                        .lineLimit(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(subtitleFont)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if entry.isFolder {
                    Image(systemName: "chevron.right")
                        .font(chevronFont)
                        .foregroundStyle(.secondary)
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
            if isLibraryFolder {
                label += ", in library"
            }
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
        return .body
        #endif
    }

    private var subtitleFont: Font {
        #if os(tvOS)
        return .callout
        #else
        return .caption
        #endif
    }

    private var chevronFont: Font {
        #if os(tvOS)
        return .body
        #else
        return .caption
        #endif
    }

    private var libraryBadgeSize: CGFloat {
        #if os(tvOS)
        return 14
        #else
        return 10
        #endif
    }

    private var libraryBadgePadding: CGFloat {
        #if os(tvOS)
        return 4
        #else
        return 2
        #endif
    }

    private var libraryBadgeOffset: CGFloat {
        #if os(tvOS)
        return 6
        #else
        return 4
        #endif
    }
}
