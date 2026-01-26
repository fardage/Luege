import SwiftUI

struct BreadcrumbBar: View {
    let breadcrumbs: [BreadcrumbItem]
    let onTap: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    breadcrumbButton(for: item, isLast: index == breadcrumbs.count - 1)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func breadcrumbButton(for item: BreadcrumbItem, isLast: Bool) -> some View {
        if isLast {
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        } else {
            Button {
                onTap(item.pathIndex)
            } label: {
                Text(item.name)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}
