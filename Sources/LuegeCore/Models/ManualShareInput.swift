import Foundation

/// Supported network share protocols
public enum ShareProtocol: String, Sendable, CaseIterable {
    case smb = "SMB"
    case nfs = "NFS"  // Future support (E1-004)
}

/// User input for manually adding a share
public struct ManualShareInput: Sendable {
    public let `protocol`: ShareProtocol
    public let host: String
    public let shareName: String
    public let credentials: ShareCredentials?

    public init(
        protocol: ShareProtocol,
        host: String,
        shareName: String,
        credentials: ShareCredentials? = nil
    ) {
        self.protocol = `protocol`
        self.host = host
        self.shareName = shareName
        self.credentials = credentials
    }
}
