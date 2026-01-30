import Foundation

/// Represents an open source library and its license information
struct OpenSourceLicense: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let version: String
    let description: String
    let licenseType: String
    let licenseText: String
    let sourceURL: String?
}
