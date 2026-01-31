import XCTest
@testable import Luege

@MainActor
final class LibraryViewTests: XCTestCase {
    var libraryService: LibraryService!
    var shareManager: ShareManager!
    var mockStorage: MockLibraryFolderStore!
    var mockScanner: MockFolderScanner!
    var mockFileStorage: MockLibraryFileStorage!

    // Test shares
    var share1: SavedShare!
    var share2: SavedShare!

    override func setUp() async throws {
        try await super.setUp()

        mockStorage = MockLibraryFolderStore()
        mockScanner = MockFolderScanner()
        mockFileStorage = MockLibraryFileStorage()

        libraryService = LibraryService(
            storage: mockStorage,
            scanner: mockScanner,
            scanCoordinator: LibraryScanCoordinator(
                scanner: mockScanner,
                fileStorage: mockFileStorage,
                browserFactory: { MockDirectoryBrowser() }
            ),
            fileStorage: mockFileStorage,
            browserFactory: { MockDirectoryBrowser() }
        )

        shareManager = ShareManager(
            connectionTester: MockConnectionTester(),
            persistenceService: SavedShareStorageService(
                credentialStore: MockCredentialStore(),
                metadataStore: MockShareMetadataStore()
            ),
            statusService: ConnectionStatusService(statusChecker: MockStatusChecker())
        )

        // Create test shares
        share1 = SavedShare(hostName: "NAS1", hostAddress: "192.168.1.100", shareName: "Media")
        share2 = SavedShare(hostName: "NAS2", hostAddress: "192.168.1.101", shareName: "Backup")
    }

    override func tearDown() async throws {
        libraryService = nil
        shareManager = nil
        mockStorage = nil
        mockScanner = nil
        mockFileStorage = nil
        share1 = nil
        share2 = nil
        try await super.tearDown()
    }

    // MARK: - Empty State Tests

    func testIsEmptyWhenNoFolders() {
        XCTAssertTrue(libraryService.libraryFolders.isEmpty)
    }

    func testIsNotEmptyWhenFoldersExist() async throws {
        _ = try await libraryService.addFolder(
            path: "Movies",
            share: share1,
            contentType: .movies,
            credentials: nil
        )

        XCTAssertFalse(libraryService.libraryFolders.isEmpty)
        XCTAssertEqual(libraryService.libraryFolders.count, 1)
    }

    // MARK: - Grouping Tests

    func testActiveContentTypes() async throws {
        _ = try await libraryService.addFolder(
            path: "Movies",
            share: share1,
            contentType: .movies,
            credentials: nil
        )
        _ = try await libraryService.addFolder(
            path: "TV",
            share: share1,
            contentType: .tvShows,
            credentials: nil
        )

        let activeTypes = LibraryContentType.allCases.filter { contentType in
            !libraryService.folders(for: contentType).isEmpty
        }

        XCTAssertEqual(activeTypes.count, 2)
        XCTAssertTrue(activeTypes.contains(.movies))
        XCTAssertTrue(activeTypes.contains(.tvShows))
        XCTAssertFalse(activeTypes.contains(.homeVideos))
        XCTAssertFalse(activeTypes.contains(.other))
    }

    func testActiveContentTypesEmpty() {
        let activeTypes = LibraryContentType.allCases.filter { contentType in
            !libraryService.folders(for: contentType).isEmpty
        }
        XCTAssertTrue(activeTypes.isEmpty)
    }

    func testFoldersForContentType() async throws {
        _ = try await libraryService.addFolder(
            path: "Movies",
            share: share1,
            contentType: .movies,
            displayName: "My Movies",
            credentials: nil
        )
        _ = try await libraryService.addFolder(
            path: "Action",
            share: share1,
            contentType: .movies,
            displayName: "Action Films",
            credentials: nil
        )
        _ = try await libraryService.addFolder(
            path: "TV",
            share: share1,
            contentType: .tvShows,
            credentials: nil
        )

        let movieFolders = libraryService.folders(for: .movies)
        let tvFolders = libraryService.folders(for: .tvShows)

        XCTAssertEqual(movieFolders.count, 2)
        XCTAssertEqual(tvFolders.count, 1)
    }

    func testFoldersCanBeSortedAlphabetically() async throws {
        _ = try await libraryService.addFolder(
            path: "Zebra",
            share: share1,
            contentType: .movies,
            displayName: "Zebra Movies",
            credentials: nil
        )
        _ = try await libraryService.addFolder(
            path: "Alpha",
            share: share1,
            contentType: .movies,
            displayName: "Alpha Movies",
            credentials: nil
        )
        _ = try await libraryService.addFolder(
            path: "Beta",
            share: share1,
            contentType: .movies,
            displayName: "Beta Movies",
            credentials: nil
        )

        let folders = libraryService.folders(for: .movies)
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        XCTAssertEqual(folders[0].displayName, "Alpha Movies")
        XCTAssertEqual(folders[1].displayName, "Beta Movies")
        XCTAssertEqual(folders[2].displayName, "Zebra Movies")
    }

    // MARK: - Share Lookup Tests

    func testSavedShareLookup() async throws {
        // Add share to manager
        let metadataStore = MockShareMetadataStore()
        metadataStore.preloadShares([share1])
        shareManager = ShareManager(
            connectionTester: MockConnectionTester(),
            persistenceService: SavedShareStorageService(
                credentialStore: MockCredentialStore(),
                metadataStore: metadataStore
            ),
            statusService: ConnectionStatusService(statusChecker: MockStatusChecker())
        )
        try await shareManager.loadSavedShares()

        let folder = try await libraryService.addFolder(
            path: "Movies",
            share: share1,
            contentType: .movies,
            credentials: nil
        )

        let foundShare = shareManager.savedShare(for: folder.shareId)

        XCTAssertNotNil(foundShare)
        XCTAssertEqual(foundShare?.id, share1.id)
    }

    func testShareStatusLookup() async throws {
        let folder = try await libraryService.addFolder(
            path: "Movies",
            share: share1,
            contentType: .movies,
            credentials: nil
        )

        let status = shareManager.shareStatuses[folder.shareId] ?? .unknown

        // Default status is unknown when share not in manager
        XCTAssertEqual(status, .unknown)
    }

    // MARK: - Remove Folder Tests

    func testRemoveFolder() async throws {
        let folder = try await libraryService.addFolder(
            path: "Movies",
            share: share1,
            contentType: .movies,
            credentials: nil
        )

        XCTAssertFalse(libraryService.libraryFolders.isEmpty)

        try libraryService.removeFolder(folder)

        XCTAssertTrue(libraryService.libraryFolders.isEmpty)
    }
}
