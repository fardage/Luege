import SwiftUI

struct EmptySourcesView: View {
    let onAddTapped: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Sources", systemImage: "externaldrive.badge.wifi")
        } description: {
            Text("Add a network share to get started")
        } actions: {
            Button(action: onAddTapped) {
                Text("Add Share")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    EmptySourcesView {
        print("Add tapped")
    }
}
