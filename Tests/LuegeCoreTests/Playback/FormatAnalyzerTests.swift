import XCTest
@testable import LuegeCore

final class FormatAnalyzerTests: XCTestCase {

    var analyzer: FormatAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = FormatAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Container Format Tests

    func testAnalyzeMP4Format() {
        let format = analyzer.analyze(path: "/videos/movie.mp4")
        XCTAssertEqual(format.container, .mp4)
        XCTAssertTrue(format.container.isNativelySupported)
        XCTAssertFalse(format.container.requiresVLC)
    }

    func testAnalyzeM4VFormat() {
        let format = analyzer.analyze(path: "/videos/movie.m4v")
        XCTAssertEqual(format.container, .m4v)
        XCTAssertTrue(format.container.isNativelySupported)
    }

    func testAnalyzeMOVFormat() {
        let format = analyzer.analyze(path: "/videos/movie.mov")
        XCTAssertEqual(format.container, .mov)
        XCTAssertTrue(format.container.isNativelySupported)
    }

    func testAnalyzeTSFormat() {
        let format = analyzer.analyze(path: "/videos/movie.ts")
        XCTAssertEqual(format.container, .ts)
        XCTAssertTrue(format.container.isNativelySupported)
    }

    func testAnalyzeMKVFormat() {
        let format = analyzer.analyze(path: "/videos/movie.mkv")
        XCTAssertEqual(format.container, .mkv)
        XCTAssertFalse(format.container.isNativelySupported)
        XCTAssertTrue(format.container.requiresVLC)
    }

    func testAnalyzeAVIFormat() {
        let format = analyzer.analyze(path: "/videos/movie.avi")
        XCTAssertEqual(format.container, .avi)
        XCTAssertFalse(format.container.isNativelySupported)
        XCTAssertTrue(format.container.requiresVLC)
    }

    func testAnalyzeWMVFormat() {
        let format = analyzer.analyze(path: "/videos/movie.wmv")
        XCTAssertEqual(format.container, .wmv)
        XCTAssertFalse(format.container.isNativelySupported)
        XCTAssertTrue(format.container.requiresVLC)
    }

    func testAnalyzeWEBMFormat() {
        let format = analyzer.analyze(path: "/videos/movie.webm")
        XCTAssertEqual(format.container, .webm)
        XCTAssertFalse(format.container.isNativelySupported)
        XCTAssertTrue(format.container.requiresVLC)
    }

    func testAnalyzeUnknownFormat() {
        let format = analyzer.analyze(path: "/videos/document.pdf")
        XCTAssertEqual(format.container, .unknown)
        XCTAssertFalse(format.container.isNativelySupported)
    }

    // MARK: - Case Insensitivity Tests

    func testAnalyzeUppercaseExtension() {
        let format = analyzer.analyze(path: "/videos/movie.MP4")
        XCTAssertEqual(format.container, .mp4)
    }

    func testAnalyzeMixedCaseExtension() {
        let format = analyzer.analyze(path: "/videos/movie.MkV")
        XCTAssertEqual(format.container, .mkv)
    }

    // MARK: - FileEntry Analysis Tests

    func testAnalyzeFileEntry() {
        let file = FileEntry(
            name: "movie.mkv",
            path: "/videos/movie.mkv",
            type: .file,
            size: 1024
        )
        let format = analyzer.analyze(file: file)
        XCTAssertEqual(format.container, .mkv)
    }

    // MARK: - Native Player Decision Tests

    func testNativeFormatsCanUseNativePlayer() {
        let nativeFormats = ["mp4", "m4v", "mov", "ts"]
        for ext in nativeFormats {
            let format = analyzer.analyze(path: "/video.\(ext)")
            XCTAssertTrue(format.canUseNativePlayer, "Expected \(ext) to use native player")
            XCTAssertFalse(format.requiresVLC, "Expected \(ext) to not require VLC")
        }
    }

    func testVLCRequiredFormats() {
        let vlcFormats = ["mkv", "avi", "wmv", "webm"]
        for ext in vlcFormats {
            let format = analyzer.analyze(path: "/video.\(ext)")
            XCTAssertFalse(format.canUseNativePlayer, "Expected \(ext) to not use native player")
            XCTAssertTrue(format.requiresVLC, "Expected \(ext) to require VLC")
        }
    }

    // MARK: - WebM Codec Tests

    func testWebMHasVP9Codec() {
        let format = analyzer.analyze(path: "/video.webm")
        XCTAssertEqual(format.videoCodec, .vp9)
        XCTAssertTrue(format.audioCodecs.contains(.opus) || format.audioCodecs.contains(.vorbis))
    }

    // MARK: - Display Name Tests

    func testContainerDisplayNames() {
        XCTAssertEqual(ContainerFormat.mp4.displayName, "MP4")
        XCTAssertEqual(ContainerFormat.mkv.displayName, "Matroska")
        XCTAssertEqual(ContainerFormat.webm.displayName, "WebM")
        XCTAssertEqual(ContainerFormat.wmv.displayName, "Windows Media")
    }

    func testVideoCodecDisplayNames() {
        XCTAssertEqual(VideoCodec.h264.displayName, "H.264")
        XCTAssertEqual(VideoCodec.h265.displayName, "H.265/HEVC")
        XCTAssertEqual(VideoCodec.vp9.displayName, "VP9")
    }

    func testAudioCodecDisplayNames() {
        XCTAssertEqual(AudioCodec.aac.displayName, "AAC")
        XCTAssertEqual(AudioCodec.dts.displayName, "DTS")
        XCTAssertEqual(AudioCodec.truehd.displayName, "Dolby TrueHD")
    }
}
