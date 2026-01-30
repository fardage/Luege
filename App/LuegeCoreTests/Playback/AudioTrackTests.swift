import XCTest
@testable import Luege

final class AudioTrackTests: XCTestCase {

    // MARK: - Display Name Tests

    func testDisplayName_withLanguageNameAndCodec() {
        let track = AudioTrack(
            id: "1",
            index: 0,
            languageCode: "en",
            languageName: "English",
            codec: .ac3,
            channels: 6,
            isDefault: true
        )

        XCTAssertEqual(track.displayName, "English - AC3 5.1")
    }

    func testDisplayName_withLanguageCodeOnly() {
        let track = AudioTrack(
            id: "1",
            index: 0,
            languageCode: "de",
            languageName: nil,
            codec: .aac,
            channels: 2
        )

        // Should use localized language name from code
        let expectedLanguage = Locale.current.localizedString(forLanguageCode: "de") ?? "DE"
        XCTAssertEqual(track.displayName, "\(expectedLanguage) - AAC Stereo")
    }

    func testDisplayName_withNoLanguage() {
        let track = AudioTrack(
            id: "1",
            index: 2,
            languageCode: nil,
            languageName: nil,
            codec: .dts,
            channels: 8
        )

        XCTAssertEqual(track.displayName, "Track 3 - DTS 7.1")
    }

    func testDisplayName_withUnknownCodec() {
        let track = AudioTrack(
            id: "1",
            index: 0,
            languageCode: nil,
            languageName: "Japanese",
            codec: .unknown,
            channels: nil
        )

        XCTAssertEqual(track.displayName, "Japanese")
    }

    func testDisplayName_monoChannel() {
        let track = AudioTrack(
            id: "1",
            index: 0,
            languageName: "Commentary",
            codec: .aac,
            channels: 1
        )

        XCTAssertEqual(track.displayName, "Commentary - AAC Mono")
    }

    func testDisplayName_stereoChannel() {
        let track = AudioTrack(
            id: "1",
            index: 0,
            languageName: "French",
            codec: .mp3,
            channels: 2
        )

        XCTAssertEqual(track.displayName, "French - MP3 Stereo")
    }

    func testDisplayName_51Channel() {
        let track = AudioTrack(
            id: "1",
            index: 0,
            languageName: "English",
            codec: .eac3,
            channels: 6
        )

        XCTAssertEqual(track.displayName, "English - E-AC3 5.1")
    }

    func testDisplayName_71Channel() {
        let track = AudioTrack(
            id: "1",
            index: 0,
            languageName: "English",
            codec: .truehd,
            channels: 8
        )

        XCTAssertEqual(track.displayName, "English - TrueHD 7.1")
    }

    func testDisplayName_unusualChannelCount() {
        let track = AudioTrack(
            id: "1",
            index: 0,
            languageName: "English",
            codec: .flac,
            channels: 4
        )

        XCTAssertEqual(track.displayName, "English - FLAC 4ch")
    }

    // MARK: - Identifiable Tests

    func testIdentifiable() {
        let track1 = AudioTrack(id: "track-1", index: 0)
        let track2 = AudioTrack(id: "track-2", index: 1)
        let track3 = AudioTrack(id: "track-1", index: 2)

        XCTAssertNotEqual(track1.id, track2.id)
        XCTAssertEqual(track1.id, track3.id)
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        let track1 = AudioTrack(
            id: "1",
            index: 0,
            languageName: "English",
            codec: .ac3,
            channels: 6,
            isDefault: true
        )

        let track2 = AudioTrack(
            id: "1",
            index: 0,
            languageName: "English",
            codec: .ac3,
            channels: 6,
            isDefault: true
        )

        let track3 = AudioTrack(
            id: "2",
            index: 1,
            languageName: "French",
            codec: .aac,
            channels: 2
        )

        XCTAssertEqual(track1, track2)
        XCTAssertNotEqual(track1, track3)
    }

    // MARK: - AudioCodec Short Display Name Tests

    func testAudioCodecShortDisplayNames() {
        XCTAssertEqual(AudioCodec.aac.shortDisplayName, "AAC")
        XCTAssertEqual(AudioCodec.ac3.shortDisplayName, "AC3")
        XCTAssertEqual(AudioCodec.eac3.shortDisplayName, "E-AC3")
        XCTAssertEqual(AudioCodec.dts.shortDisplayName, "DTS")
        XCTAssertEqual(AudioCodec.truehd.shortDisplayName, "TrueHD")
        XCTAssertEqual(AudioCodec.flac.shortDisplayName, "FLAC")
        XCTAssertEqual(AudioCodec.mp3.shortDisplayName, "MP3")
        XCTAssertEqual(AudioCodec.opus.shortDisplayName, "Opus")
        XCTAssertEqual(AudioCodec.vorbis.shortDisplayName, "Vorbis")
        XCTAssertEqual(AudioCodec.unknown.shortDisplayName, "")
    }
}
