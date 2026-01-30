import XCTest
@testable import Luege

final class SubtitleTrackTests: XCTestCase {

    // MARK: - SubtitleTrack Tests

    func testSubtitleTrackDisplayNameWithLanguageName() {
        let track = SubtitleTrack(
            id: "test-1",
            index: 0,
            languageCode: "en",
            languageName: "English",
            format: .srt,
            isEmbedded: true
        )

        XCTAssertEqual(track.displayName, "English - SRT")
    }

    func testSubtitleTrackDisplayNameWithLanguageCodeOnly() {
        let track = SubtitleTrack(
            id: "test-1",
            index: 0,
            languageCode: "de",
            languageName: nil,
            format: .ass
        )

        // Should use localized name from language code
        XCTAssertTrue(track.displayName.contains("ASS"))
    }

    func testSubtitleTrackDisplayNameFallbackToTrackNumber() {
        let track = SubtitleTrack(
            id: "test-1",
            index: 2,
            languageCode: nil,
            languageName: nil,
            format: .unknown
        )

        XCTAssertEqual(track.displayName, "Track 3")
    }

    func testSubtitleTrackDisplayNameWithForced() {
        let track = SubtitleTrack(
            id: "test-1",
            index: 0,
            languageCode: "en",
            languageName: "English",
            format: .srt,
            isEmbedded: true,
            isDefault: false,
            isForced: true
        )

        XCTAssertTrue(track.displayName.contains("Forced"))
        XCTAssertTrue(track.displayName.contains("English"))
    }

    func testSubtitleTrackDisplayNameWithExternal() {
        let track = SubtitleTrack(
            id: "test-1",
            index: 0,
            languageCode: "en",
            languageName: "English",
            format: .srt,
            isEmbedded: false
        )

        XCTAssertTrue(track.displayName.contains("External"))
    }

    func testSubtitleTrackEquality() {
        let track1 = SubtitleTrack(
            id: "test-1",
            index: 0,
            languageCode: "en",
            languageName: "English",
            format: .srt
        )

        let track2 = SubtitleTrack(
            id: "test-1",
            index: 0,
            languageCode: "en",
            languageName: "English",
            format: .srt
        )

        let track3 = SubtitleTrack(
            id: "test-2",
            index: 1,
            languageCode: "de",
            languageName: "German",
            format: .ass
        )

        XCTAssertEqual(track1, track2)
        XCTAssertNotEqual(track1, track3)
    }

    // MARK: - SubtitleFormat Tests

    func testSubtitleFormatDisplayNames() {
        XCTAssertEqual(SubtitleFormat.srt.displayName, "SRT")
        XCTAssertEqual(SubtitleFormat.ass.displayName, "ASS")
        XCTAssertEqual(SubtitleFormat.ssa.displayName, "SSA")
        XCTAssertEqual(SubtitleFormat.pgs.displayName, "PGS")
        XCTAssertEqual(SubtitleFormat.vobsub.displayName, "VobSub")
        XCTAssertEqual(SubtitleFormat.webvtt.displayName, "WebVTT")
        XCTAssertEqual(SubtitleFormat.dvbsub.displayName, "DVB")
        XCTAssertEqual(SubtitleFormat.cc608.displayName, "CC")
        XCTAssertEqual(SubtitleFormat.cc708.displayName, "CC")
        XCTAssertEqual(SubtitleFormat.unknown.displayName, "")
    }

    func testSubtitleFormatFromExtension() {
        XCTAssertEqual(SubtitleFormat(fromExtension: "srt"), .srt)
        XCTAssertEqual(SubtitleFormat(fromExtension: "SRT"), .srt)
        XCTAssertEqual(SubtitleFormat(fromExtension: "ass"), .ass)
        XCTAssertEqual(SubtitleFormat(fromExtension: "ssa"), .ssa)
        XCTAssertEqual(SubtitleFormat(fromExtension: "sub"), .sub)
        XCTAssertEqual(SubtitleFormat(fromExtension: "vtt"), .webvtt)
        XCTAssertEqual(SubtitleFormat(fromExtension: "idx"), .vobsub)
        XCTAssertEqual(SubtitleFormat(fromExtension: "xyz"), .unknown)
    }

    func testSubtitleFormatCaseIterable() {
        let allFormats = SubtitleFormat.allCases
        XCTAssertTrue(allFormats.contains(.srt))
        XCTAssertTrue(allFormats.contains(.ass))
        XCTAssertTrue(allFormats.contains(.pgs))
        XCTAssertTrue(allFormats.contains(.unknown))
    }

    // MARK: - SubtitleTrack Identifiable

    func testSubtitleTrackIdentifiable() {
        let track = SubtitleTrack(
            id: "unique-id-123",
            index: 0
        )

        XCTAssertEqual(track.id, "unique-id-123")
    }
}
