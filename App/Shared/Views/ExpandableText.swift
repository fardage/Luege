import SwiftUI

/// A text view that truncates to a configurable number of lines
/// and shows a MORE/LESS button when the text overflows.
struct ExpandableText: View {
    let text: String
    var lineLimit: Int = 3

    @State private var isExpanded = false
    @State private var isTruncated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : lineLimit)
                .background(
                    // Measure full-height text to detect truncation
                    Text(text)
                        .font(.body)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .background(GeometryReader { fullGeometry in
                            Color.clear
                                .preference(key: FullHeightKey.self, value: fullGeometry.size.height)
                        })
                        .frame(height: 0)
                        .clipped()
                )
                .background(GeometryReader { visibleGeometry in
                    Color.clear
                        .preference(key: VisibleHeightKey.self, value: visibleGeometry.size.height)
                })

            if isTruncated {
                Button(isExpanded ? "LESS" : "MORE") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .buttonStyle(.plain)
            }
        }
        .onPreferenceChange(FullHeightKey.self) { fullHeight in
            // We'll compare in the combined handler below
            checkTruncation(fullHeight: fullHeight, visibleHeight: nil)
        }
        .onPreferenceChange(VisibleHeightKey.self) { visibleHeight in
            checkTruncation(fullHeight: nil, visibleHeight: visibleHeight)
        }
    }

    // Store heights for comparison
    @State private var fullHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0

    private func checkTruncation(fullHeight: CGFloat?, visibleHeight: CGFloat?) {
        if let fullHeight {
            self.fullHeight = fullHeight
        }
        if let visibleHeight {
            self.visibleHeight = visibleHeight
        }
        if self.fullHeight > 0 && self.visibleHeight > 0 {
            let truncated = self.fullHeight > self.visibleHeight + 1
            if truncated != isTruncated && !isExpanded {
                isTruncated = truncated
            }
        }
    }
}

// MARK: - Preference Keys

private struct FullHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct VisibleHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
