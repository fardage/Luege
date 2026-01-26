import XCTest
@testable import LuegeCore

final class FileEntryTests: XCTestCase {

    // MARK: - Type Detection

    func testIsFolderForFolderType() {
        let entry = FileEntry(name: "Documents", path: "Documents", type: .folder)
        XCTAssertTrue(entry.isFolder)
    }

    func testIsFolderForFileType() {
        let entry = FileEntry(name: "movie.mp4", path: "movie.mp4", type: .file)
        XCTAssertFalse(entry.isFolder)
    }

    // MARK: - File Extension

    func testFileExtensionForFile() {
        let entry = FileEntry(name: "movie.mp4", path: "movie.mp4", type: .file)
        XCTAssertEqual(entry.fileExtension, "mp4")
    }

    func testFileExtensionForFileWithUppercase() {
        let entry = FileEntry(name: "movie.MKV", path: "movie.MKV", type: .file)
        XCTAssertEqual(entry.fileExtension, "mkv")
    }

    func testFileExtensionForFolder() {
        let entry = FileEntry(name: "folder.name", path: "folder.name", type: .folder)
        XCTAssertEqual(entry.fileExtension, "")
    }

    func testFileExtensionForFileWithoutExtension() {
        let entry = FileEntry(name: "README", path: "README", type: .file)
        XCTAssertEqual(entry.fileExtension, "")
    }

    // MARK: - Video Detection

    func testIsVideoFileForMp4() {
        let entry = FileEntry(name: "movie.mp4", path: "movie.mp4", type: .file)
        XCTAssertTrue(entry.isVideoFile)
    }

    func testIsVideoFileForMkv() {
        let entry = FileEntry(name: "movie.mkv", path: "movie.mkv", type: .file)
        XCTAssertTrue(entry.isVideoFile)
    }

    func testIsVideoFileForAvi() {
        let entry = FileEntry(name: "movie.avi", path: "movie.avi", type: .file)
        XCTAssertTrue(entry.isVideoFile)
    }

    func testIsVideoFileForMov() {
        let entry = FileEntry(name: "movie.mov", path: "movie.mov", type: .file)
        XCTAssertTrue(entry.isVideoFile)
    }

    func testIsVideoFileForWmv() {
        let entry = FileEntry(name: "movie.wmv", path: "movie.wmv", type: .file)
        XCTAssertTrue(entry.isVideoFile)
    }

    func testIsVideoFileForM4v() {
        let entry = FileEntry(name: "movie.m4v", path: "movie.m4v", type: .file)
        XCTAssertTrue(entry.isVideoFile)
    }

    func testIsVideoFileForTs() {
        let entry = FileEntry(name: "movie.ts", path: "movie.ts", type: .file)
        XCTAssertTrue(entry.isVideoFile)
    }

    func testIsVideoFileForWebm() {
        let entry = FileEntry(name: "movie.webm", path: "movie.webm", type: .file)
        XCTAssertTrue(entry.isVideoFile)
    }

    func testIsVideoFileWithUppercaseExtension() {
        let entry = FileEntry(name: "movie.MP4", path: "movie.MP4", type: .file)
        XCTAssertTrue(entry.isVideoFile)
    }

    func testIsVideoFileForNonVideo() {
        let entry = FileEntry(name: "document.pdf", path: "document.pdf", type: .file)
        XCTAssertFalse(entry.isVideoFile)
    }

    func testIsVideoFileForFolder() {
        let entry = FileEntry(name: "videos.mp4", path: "videos.mp4", type: .folder)
        XCTAssertFalse(entry.isVideoFile)
    }

    // MARK: - Formatted Size

    func testFormattedSizeForSmallFile() {
        let entry = FileEntry(name: "file.txt", path: "file.txt", type: .file, size: 1024)
        XCTAssertNotNil(entry.formattedSize)
        XCTAssertEqual(entry.formattedSize, "1 KB")
    }

    func testFormattedSizeForLargeFile() {
        let entry = FileEntry(name: "movie.mp4", path: "movie.mp4", type: .file, size: 1_500_000_000)
        XCTAssertNotNil(entry.formattedSize)
        // Should contain GB
        XCTAssertTrue(entry.formattedSize?.contains("GB") == true)
    }

    func testFormattedSizeForFolder() {
        let entry = FileEntry(name: "folder", path: "folder", type: .folder, size: 1024)
        XCTAssertNil(entry.formattedSize)
    }

    func testFormattedSizeWhenSizeNil() {
        let entry = FileEntry(name: "file.txt", path: "file.txt", type: .file, size: nil)
        XCTAssertNil(entry.formattedSize)
    }

    // MARK: - Formatted Date

    func testFormattedDateWhenPresent() {
        let date = Date()
        let entry = FileEntry(name: "file.txt", path: "file.txt", type: .file, modifiedDate: date)
        XCTAssertNotNil(entry.formattedDate)
    }

    func testFormattedDateWhenNil() {
        let entry = FileEntry(name: "file.txt", path: "file.txt", type: .file, modifiedDate: nil)
        XCTAssertNil(entry.formattedDate)
    }

    // MARK: - Equality

    func testEqualityById() {
        let id = UUID()
        let entry1 = FileEntry(id: id, name: "file.txt", path: "file.txt", type: .file)
        let entry2 = FileEntry(id: id, name: "file.txt", path: "file.txt", type: .file)
        XCTAssertEqual(entry1, entry2)
    }

    func testInequalityByDifferentId() {
        let entry1 = FileEntry(name: "file.txt", path: "file.txt", type: .file)
        let entry2 = FileEntry(name: "file.txt", path: "file.txt", type: .file)
        XCTAssertNotEqual(entry1, entry2)
    }

    // MARK: - Video Extensions Set

    func testAllSupportedVideoExtensions() {
        let expected: Set<String> = ["mkv", "mp4", "avi", "mov", "wmv", "m4v", "ts", "webm"]
        XCTAssertEqual(FileEntry.videoExtensions, expected)
    }
}
