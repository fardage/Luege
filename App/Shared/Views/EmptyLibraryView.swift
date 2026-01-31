import SwiftUI

struct EmptyLibraryView: View {
    let onGoToSourcesTapped: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Library Folders", systemImage: "books.vertical")
        } description: {
            Text("Add folders from your sources to build your library")
        } actions: {
            Button(action: onGoToSourcesTapped) {
                Text("Go to Sources")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    EmptyLibraryView {
        print("Go to Sources tapped")
    }
}
