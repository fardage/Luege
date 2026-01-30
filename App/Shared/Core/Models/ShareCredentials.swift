import Foundation

/// Credentials for authenticating to an SMB share
struct ShareCredentials: Sendable, Hashable {
    let username: String
    let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    /// Guest credentials for anonymous access
    static let guest = ShareCredentials(username: "guest", password: "guest")
}
