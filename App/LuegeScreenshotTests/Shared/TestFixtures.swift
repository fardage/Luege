import Foundation
@testable import Luege

/// Mock data factories for consistent, deterministic snapshots
enum TestFixtures {
    // MARK: - Fixed UUIDs for deterministic snapshots

    static let uuid1 = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let uuid2 = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let uuid3 = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let uuid4 = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    // MARK: - Fixed Date for deterministic snapshots

    static let fixedDate = Date(timeIntervalSince1970: 0)

    // MARK: - SavedShare Fixtures

    static let savedShareOnline = SavedShare(
        id: uuid1,
        hostName: "NAS-Server",
        hostAddress: "192.168.1.100",
        shareName: "Movies",
        displayName: "My Movies",
        credentialId: nil,
        savedAt: fixedDate
    )

    static let savedShareOffline = SavedShare(
        id: uuid2,
        hostName: "Media-Center",
        hostAddress: "192.168.1.200",
        shareName: "Music",
        displayName: "Music Library",
        credentialId: nil,
        savedAt: fixedDate
    )

    static let savedShareChecking = SavedShare(
        id: uuid3,
        hostName: "Backup-Server",
        hostAddress: "192.168.1.50",
        shareName: "Backup",
        displayName: "Backup Drive",
        credentialId: nil,
        savedAt: fixedDate
    )

    static let savedShareUnknown = SavedShare(
        id: uuid4,
        hostName: "New-Server",
        hostAddress: "192.168.1.150",
        shareName: "Data",
        displayName: "Data Storage",
        credentialId: nil,
        savedAt: fixedDate
    )

    static let savedShareLongName = SavedShare(
        id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
        hostName: "VeryLongServerName",
        hostAddress: "192.168.1.250",
        shareName: "SharedMediaLibraryWithVeryLongName",
        displayName: "This Is A Very Long Display Name That Should Be Truncated In The UI",
        credentialId: nil,
        savedAt: fixedDate
    )

    // MARK: - DiscoveredShare Fixtures

    static let discoveredShareWithComment = DiscoveredShare(
        id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
        hostName: "Office-NAS",
        hostAddress: "10.0.0.50",
        shareName: "Documents",
        comment: "Shared documents folder",
        discoveredAt: fixedDate,
        isManuallyAdded: false
    )

    static let discoveredShareWithoutComment = DiscoveredShare(
        id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
        hostName: "Home-Server",
        hostAddress: "192.168.0.100",
        shareName: "Photos",
        comment: nil,
        discoveredAt: fixedDate,
        isManuallyAdded: false
    )

    static let discoveredShareManual = DiscoveredShare(
        id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
        hostName: "External-Server",
        hostAddress: "external.example.com",
        shareName: "Public",
        comment: nil,
        discoveredAt: fixedDate,
        isManuallyAdded: true
    )

    // MARK: - Status Maps

    static let statusesAllOnline: [UUID: ConnectionStatus] = [
        uuid1: .online,
        uuid2: .online,
        uuid3: .online,
        uuid4: .online
    ]

    static let statusesAllOffline: [UUID: ConnectionStatus] = [
        uuid1: .offline(reason: "Connection refused"),
        uuid2: .offline(reason: "Host unreachable"),
        uuid3: .offline(reason: "Authentication failed"),
        uuid4: .offline(reason: "Timeout")
    ]

    static let statusesMixed: [UUID: ConnectionStatus] = [
        uuid1: .online,
        uuid2: .offline(reason: "Connection refused"),
        uuid3: .checking,
        uuid4: .unknown
    ]

    // MARK: - Arrays

    static let savedSharesEmpty: [SavedShare] = []

    static let savedSharesSingle = [savedShareOnline]

    static let savedSharesMultiple = [
        savedShareOnline,
        savedShareOffline,
        savedShareChecking,
        savedShareUnknown
    ]

    static let discoveredSharesEmpty: [DiscoveredShare] = []

    static let discoveredSharesSingle = [discoveredShareWithComment]

    static let discoveredSharesMultiple = [
        discoveredShareWithComment,
        discoveredShareWithoutComment,
        discoveredShareManual
    ]
}
