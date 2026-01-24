import Foundation

/// Credentials for authenticating to an SMB share
public struct ShareCredentials: Sendable, Hashable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    /// Guest credentials for anonymous access
    public static let guest = ShareCredentials(username: "guest", password: "guest")
}
