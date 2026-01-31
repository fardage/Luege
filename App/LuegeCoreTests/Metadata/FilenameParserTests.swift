import XCTest
@testable import Luege

final class FilenameParserTests: XCTestCase {
    var parser: FilenameParser!

    override func setUp() {
        super.setUp()
        parser = FilenameParser()
    }

    // MARK: - Basic Title Extraction

    func testSimpleTitle() {
        let result = parser.parse("The Matrix.mkv")
        XCTAssertEqual(result.title, "The Matrix")
        XCTAssertNil(result.year)
        XCTAssertNil(result.quality)
    }

    func testTitleWithSpaces() {
        let result = parser.parse("The Lord of the Rings.mp4")
        XCTAssertEqual(result.title, "The Lord of the Rings")
    }

    // MARK: - Year in Parentheses

    func testYearInParentheses() {
        let result = parser.parse("The Matrix (1999).mkv")
        XCTAssertEqual(result.title, "The Matrix")
        XCTAssertEqual(result.year, 1999)
    }

    func testYearInParenthesesNoSpace() {
        let result = parser.parse("The Matrix(1999).mkv")
        XCTAssertEqual(result.title, "The Matrix")
        XCTAssertEqual(result.year, 1999)
    }

    func testTitleWithParenthesesAndYear() {
        let result = parser.parse("Spider-Man (2002).mkv")
        XCTAssertEqual(result.title, "Spider-Man")
        XCTAssertEqual(result.year, 2002)
    }

    // MARK: - Year in Brackets

    func testYearInBrackets() {
        let result = parser.parse("Inception [2010].mkv")
        XCTAssertEqual(result.title, "Inception")
        XCTAssertEqual(result.year, 2010)
    }

    // MARK: - Dot-Separated Filenames

    func testDotSeparatedFilename() {
        let result = parser.parse("The.Matrix.1999.BluRay.1080p.mkv")
        XCTAssertEqual(result.title, "The Matrix")
        XCTAssertEqual(result.year, 1999)
        XCTAssertEqual(result.quality, "1080p")
    }

    func testDotSeparatedFilenameWith4K() {
        let result = parser.parse("Dune.2021.2160p.UHD.BluRay.mkv")
        XCTAssertEqual(result.title, "Dune")
        XCTAssertEqual(result.year, 2021)
        XCTAssertEqual(result.quality, "4K")
    }

    func testDotSeparatedFilenameWith720p() {
        let result = parser.parse("Interstellar.2014.720p.WEBRip.mkv")
        XCTAssertEqual(result.title, "Interstellar")
        XCTAssertEqual(result.year, 2014)
        XCTAssertEqual(result.quality, "720p")
    }

    // MARK: - Underscore and Dash Separated

    func testUnderscoreSeparated() {
        let result = parser.parse("The_Matrix_1999_1080p.mkv")
        XCTAssertEqual(result.title, "The Matrix")
        XCTAssertEqual(result.year, 1999)
        XCTAssertEqual(result.quality, "1080p")
    }

    func testDashSeparated() {
        let result = parser.parse("The-Matrix-1999-BluRay.mkv")
        XCTAssertEqual(result.title, "The Matrix")
        XCTAssertEqual(result.year, 1999)
    }

    // MARK: - Complex Release Names

    func testComplexReleaseName() {
        let result = parser.parse("The.Matrix.1999.Remastered.1080p.BluRay.x264-GROUP.mkv")
        XCTAssertEqual(result.title, "The Matrix")
        XCTAssertEqual(result.year, 1999)
        XCTAssertEqual(result.quality, "1080p")
    }

    func testReleaseWithMultipleQualityIndicators() {
        let result = parser.parse("Avatar.2009.Extended.2160p.UHD.HDR.BluRay.mkv")
        XCTAssertEqual(result.title, "Avatar")
        XCTAssertEqual(result.year, 2009)
        XCTAssertEqual(result.quality, "4K") // 2160p maps to 4K
    }

    // MARK: - Edge Cases

    func testNoYear() {
        let result = parser.parse("Some Movie.mkv")
        XCTAssertEqual(result.title, "Some Movie")
        XCTAssertNil(result.year)
    }

    func testYearAtEnd() {
        let result = parser.parse("The Matrix 1999.mkv")
        XCTAssertEqual(result.title, "The Matrix")
        XCTAssertEqual(result.year, 1999)
    }

    func testTitleWithNumbers() {
        let result = parser.parse("2001 A Space Odyssey (1968).mkv")
        XCTAssertEqual(result.title, "2001 A Space Odyssey")
        XCTAssertEqual(result.year, 1968)
    }

    func testMovieWithYearInTitle() {
        let result = parser.parse("1917 (2019).mkv")
        XCTAssertEqual(result.title, "1917")
        XCTAssertEqual(result.year, 2019)
    }

    func testSequelNumber() {
        let result = parser.parse("Blade Runner 2049 (2017).mkv")
        XCTAssertEqual(result.title, "Blade Runner 2049")
        XCTAssertEqual(result.year, 2017)
    }

    // MARK: - File Extensions

    func testMKVExtension() {
        let result = parser.parse("Movie.mkv")
        XCTAssertEqual(result.title, "Movie")
    }

    func testMP4Extension() {
        let result = parser.parse("Movie.mp4")
        XCTAssertEqual(result.title, "Movie")
    }

    func testM4VExtension() {
        let result = parser.parse("Movie.m4v")
        XCTAssertEqual(result.title, "Movie")
    }

    func testAVIExtension() {
        let result = parser.parse("Movie.avi")
        XCTAssertEqual(result.title, "Movie")
    }

    func testNoExtension() {
        let result = parser.parse("The Matrix (1999)")
        XCTAssertEqual(result.title, "The Matrix")
        XCTAssertEqual(result.year, 1999)
    }

    // MARK: - Quality Extraction

    func test1080pQuality() {
        let result = parser.parse("Movie.1080p.mkv")
        XCTAssertEqual(result.quality, "1080p")
    }

    func test720pQuality() {
        let result = parser.parse("Movie.720p.mkv")
        XCTAssertEqual(result.quality, "720p")
    }

    func test4KQuality() {
        let result = parser.parse("Movie.4K.mkv")
        XCTAssertEqual(result.quality, "4K")
    }

    func testUHDQuality() {
        let result = parser.parse("Movie.UHD.mkv")
        XCTAssertEqual(result.quality, "4K")
    }

    func testBluRayQuality() {
        let result = parser.parse("Movie.BluRay.mkv")
        XCTAssertEqual(result.quality, "BluRay")
    }

    // MARK: - Stop Words

    func testStopsAtQualityIndicator() {
        let result = parser.parse("The.Matrix.1080p.BluRay.x264.mkv")
        XCTAssertEqual(result.title, "The Matrix")
    }

    func testStopsAtReleaseGroup() {
        let result = parser.parse("The Matrix YIFY.mkv")
        XCTAssertEqual(result.title, "The Matrix")
    }

    // MARK: - Equatable

    func testFilenameParseResultEquality() {
        let result1 = FilenameParseResult(title: "The Matrix", year: 1999, quality: "1080p")
        let result2 = FilenameParseResult(title: "The Matrix", year: 1999, quality: "1080p")
        XCTAssertEqual(result1, result2)
    }

    func testFilenameParseResultInequality() {
        let result1 = FilenameParseResult(title: "The Matrix", year: 1999)
        let result2 = FilenameParseResult(title: "The Matrix", year: 2021)
        XCTAssertNotEqual(result1, result2)
    }
}
