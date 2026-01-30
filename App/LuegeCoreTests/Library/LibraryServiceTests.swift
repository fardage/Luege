import XCTest
@testable import Luege

@MainActor
final class LibraryServiceTests: XCTestCase {
    var service: LibraryService!
    var mockStorage: MockLibraryFolderStore!
    var mockScanner: MockFolderScanner!
    var mockBrowser: MockDirectoryBrowser!

    override func setUp() async throws {
        try await super.setUp()
        mockStorage = MockLibraryFolderStore()
        mockScanner = MockFolderScanner()
        mockBrowser = MockDirectoryBrowser()

        service = LibraryService(
            storage: mockStorage,
            scanner: mockScanner,
            browserFactory: { [weak self] in
                self?.mockBrowser ?? MockDirectoryBrowser()
            }
        )
    }

    override func tearDown() async throws {
        service = nil
        mockStorage = nil
        mockScanner = nil
        mockBrowser = nil
        try await super.tearDown()
    }

    // MARK: - Load Tests

    func testLoadLibraryFolders() async throws {
        let folder = LibraryFolder(
            shareId: UUID(),
            path: "Movies",
            contentType: .movies,
            displayName: "Movies"
        )
        mockStorage.folders = [folder]

        try await service.loadLibraryFolders()

        XCTAssertEqual(service.libraryFolders.count, 1)
        XCTAssertEqual(service.libraryFolders[0].path, "Movies")
        XCTAssertTrue(mockStorage.loadAllCalled)
    }

    // MARK: - Add Folder Tests

    func testAddFolder() async throws {
        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        mockScanner.setScanResult(for: "Movies", videoCount: 10)

        let folder = try await service.addFolder(
            path: "Movies",
            share: share,
            contentType: .movies,
            displayName: "My Movies",
            credentials: nil
        )

        XCTAssertEqual(folder.path, "Movies")
        XCTAssertEqual(folder.shareId, share.id)
        XCTAssertEqual(folder.contentType, .movies)
        XCTAssertEqual(folder.displayName, "My Movies")
        XCTAssertEqual(service.libraryFolders.count, 1)
        XCTAssertTrue(mockStorage.saveAllCalled)
    }

    func testAddFolderWithDefaultDisplayName() async throws {
        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")

        let folder = try await service.addFolder(
            path: "Movies/Action",
            share: share,
            contentType: .movies,
            credentials: nil
        )

        // Default display name is the last path component
        XCTAssertEqual(folder.displayName, "Action")
    }

    func testAddFolderAtRootUsesShareName() async throws {
        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")

        let folder = try await service.addFolder(
            path: "",
            share: share,
            contentType: .other,
            credentials: nil
        )

        // For root path, use share display name
        XCTAssertEqual(folder.displayName, share.displayName)
    }

    func testAddDuplicateFolderThrows() async throws {
        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")

        _ = try await service.addFolder(
            path: "Movies",
            share: share,
            contentType: .movies,
            credentials: nil
        )

        do {
            _ = try await service.addFolder(
                path: "Movies",
                share: share,
                contentType: .movies,
                credentials: nil
            )
            XCTFail("Expected folderAlreadyInLibrary error")
        } catch LibraryError.folderAlreadyInLibrary {
            // Expected
        }
    }

    // MARK: - Remove Folder Tests

    func testRemoveFolder() async throws {
        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        let folder = try await service.addFolder(
            path: "Movies",
            share: share,
            contentType: .movies,
            credentials: nil
        )

        XCTAssertEqual(service.libraryFolders.count, 1)

        try service.removeFolder(folder)

        XCTAssertEqual(service.libraryFolders.count, 0)
    }

    func testRemoveFolderById() async throws {
        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        let folder = try await service.addFolder(
            path: "Movies",
            share: share,
            contentType: .movies,
            credentials: nil
        )

        try service.removeFolder(id: folder.id)

        XCTAssertEqual(service.libraryFolders.count, 0)
    }

    func testRemoveFoldersForShare() async throws {
        let share1 = SavedShare(hostName: "NAS1", hostAddress: "192.168.1.100", shareName: "Media1")
        let share2 = SavedShare(hostName: "NAS2", hostAddress: "192.168.1.101", shareName: "Media2")

        _ = try await service.addFolder(path: "Movies", share: share1, contentType: .movies, credentials: nil)
        _ = try await service.addFolder(path: "TV", share: share1, contentType: .tvShows, credentials: nil)
        _ = try await service.addFolder(path: "Videos", share: share2, contentType: .other, credentials: nil)

        XCTAssertEqual(service.libraryFolders.count, 3)

        try service.removeFolders(for: share1.id)

        XCTAssertEqual(service.libraryFolders.count, 1)
        XCTAssertEqual(service.libraryFolders[0].shareId, share2.id)
    }

    // MARK: - Query Tests

    func testIsInLibrary() async throws {
        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        _ = try await service.addFolder(
            path: "Movies",
            share: share,
            contentType: .movies,
            credentials: nil
        )

        XCTAssertTrue(service.isInLibrary(path: "Movies", shareId: share.id))
        XCTAssertFalse(service.isInLibrary(path: "TV Shows", shareId: share.id))
        XCTAssertFalse(service.isInLibrary(path: "Movies", shareId: UUID()))
    }

    func testLibraryFolderAt() async throws {
        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        let added = try await service.addFolder(
            path: "Movies",
            share: share,
            contentType: .movies,
            credentials: nil
        )

        let found = service.libraryFolder(at: "Movies", shareId: share.id)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, added.id)

        let notFound = service.libraryFolder(at: "TV Shows", shareId: share.id)
        XCTAssertNil(notFound)
    }

    func testFoldersForShare() async throws {
        let share1 = SavedShare(hostName: "NAS1", hostAddress: "192.168.1.100", shareName: "Media1")
        let share2 = SavedShare(hostName: "NAS2", hostAddress: "192.168.1.101", shareName: "Media2")

        _ = try await service.addFolder(path: "Movies", share: share1, contentType: .movies, credentials: nil)
        _ = try await service.addFolder(path: "TV", share: share1, contentType: .tvShows, credentials: nil)
        _ = try await service.addFolder(path: "Videos", share: share2, contentType: .other, credentials: nil)

        let share1Folders = service.folders(for: share1.id)
        let share2Folders = service.folders(for: share2.id)

        XCTAssertEqual(share1Folders.count, 2)
        XCTAssertEqual(share2Folders.count, 1)
    }

    func testFoldersForContentType() async throws {
        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")

        _ = try await service.addFolder(path: "Movies", share: share, contentType: .movies, credentials: nil)
        _ = try await service.addFolder(path: "More Movies", share: share, contentType: .movies, credentials: nil)
        _ = try await service.addFolder(path: "TV", share: share, contentType: .tvShows, credentials: nil)

        let movieFolders = service.folders(for: .movies)
        let tvFolders = service.folders(for: .tvShows)

        XCTAssertEqual(movieFolders.count, 2)
        XCTAssertEqual(tvFolders.count, 1)
    }
}
