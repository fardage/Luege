import Foundation

/// Supported network share protocols
enum ShareProtocol: String, Sendable, CaseIterable {
    case smb = "SMB"
    case nfs = "NFS"  // Future support (E1-004)
}

/// User input for manually adding a share
struct ManualShareInput: Sendable {
    let `protocol`: ShareProtocol
    let host: String
    let shareName: String
    let credentials: ShareCredentials?

    init(
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
