import SwiftUI

#if !os(tvOS)
/// A vertical A-Z + "#" strip overlay for quick section navigation.
///
/// Supports both tap and continuous drag gestures. Letters without items
/// are dimmed to `.quaternary` style.
struct AlphabetSectionIndex: View {
    let activeSections: Set<String>
    let onSelectLetter: (String) -> Void

    private static let allLetters: [String] = {
        let az = (UInt32(65)...UInt32(90)).compactMap { Unicode.Scalar($0).map { String($0) } }
        return az + ["#"]
    }()

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Self.allLetters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(activeSections.contains(letter) ? .primary : .quaternary)
            }
        }
        .frame(width: 20)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    selectLetter(at: value.location.y)
                }
        )
    }

    private func selectLetter(at yPosition: CGFloat) {
        let totalLetters = Self.allLetters.count
        // Each letter takes roughly equal vertical space
        let letterHeight = CGFloat(totalLetters) * (11 + 2) // font size + spacing
        let fraction = max(0, min(yPosition / letterHeight, 1))
        let index = min(Int(fraction * CGFloat(totalLetters)), totalLetters - 1)
        guard index >= 0 else { return }
        let letter = Self.allLetters[index]
        if activeSections.contains(letter) {
            onSelectLetter(letter)
        }
    }
}
#endif
