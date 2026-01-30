import SwiftUI

struct ConnectionStatusBadge: View {
    let status: ConnectionStatus

    /// Whether running in a test environment
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some View {
        HStack(spacing: 4) {
            if status.isChecking {
                if isRunningTests {
                    // Static icon for snapshot tests (ProgressView animates)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                Image(systemName: status.iconName)
                    .foregroundStyle(status.color)
            }

            #if os(iOS)
            Text(status.shortText)
                .font(.caption)
                .foregroundStyle(status.color)
            #endif
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.displayText)
    }
}

#Preview {
    VStack(spacing: 20) {
        ConnectionStatusBadge(status: .unknown)
        ConnectionStatusBadge(status: .checking)
        ConnectionStatusBadge(status: .online)
        ConnectionStatusBadge(status: .offline(reason: "Connection refused"))
    }
    .padding()
}
