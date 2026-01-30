import SwiftUI

@MainActor
final class AddShareViewModel: ObservableObject {
    @Published var host: String = ""
    @Published var shareName: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var displayName: String = ""

    @Published var isTesting: Bool = false
    @Published var isSaving: Bool = false
    @Published var testResult: TestResult?
    @Published var errorMessage: String?
    @Published var isShowingError = false

    enum TestResult {
        case success
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }

        var message: String {
            switch self {
            case .success:
                return "Connection successful"
            case .failure(let reason):
                return reason
            }
        }
    }

    private let discoveryService: NetworkDiscoveryService
    private var testedShare: DiscoveredShare?

    var isFormValid: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !shareName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canSave: Bool {
        isFormValid && testResult?.isSuccess == true && !isSaving
    }

    var effectiveDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "\(host)/\(shareName)" : trimmed
    }

    private var credentials: ShareCredentials? {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        guard !trimmedUsername.isEmpty else { return nil }
        return ShareCredentials(username: trimmedUsername, password: password)
    }

    init(discoveryService: NetworkDiscoveryService) {
        self.discoveryService = discoveryService
    }

    func testConnection() async {
        guard isFormValid else { return }

        isTesting = true
        testResult = nil
        testedShare = nil

        let input = ManualShareInput(
            protocol: .smb,
            host: host.trimmingCharacters(in: .whitespaces),
            shareName: shareName.trimmingCharacters(in: .whitespaces),
            credentials: credentials
        )

        do {
            let share = try await discoveryService.addManualShare(input)
            testedShare = share
            testResult = .success
        } catch {
            testResult = .failure(error.localizedDescription)
        }

        isTesting = false
    }

    func save() async -> Bool {
        guard canSave, let share = testedShare else { return false }

        isSaving = true

        do {
            _ = try await discoveryService.saveShare(
                share,
                credentials: credentials,
                displayName: displayName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : displayName.trimmingCharacters(in: .whitespaces)
            )
            isSaving = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
            isSaving = false
            return false
        }
    }

    func reset() {
        host = ""
        shareName = ""
        username = ""
        password = ""
        displayName = ""
        testResult = nil
        testedShare = nil
        errorMessage = nil
    }
}
