import XCTest
@testable import Luege

final class TVShowFilenameParserTests: XCTestCase {
    var parser: TVShowFilenameParser!

    override func setUp() {
        super.setUp()
        parser = TVShowFilenameParser()
    }

    // MARK: - Standard S01E03 Pattern

    func testStandardPattern() {
        let result = parser.parse("Game.of.Thrones.S01E03.mkv")
        XCTAssertEqual(result.showName, "Game of Thrones")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
        XCTAssertTrue(result.isValid)
    }

    func testStandardPatternWithSpaces() {
        let result = parser.parse("Game of Thrones S01E03.mkv")
        XCTAssertEqual(result.showName, "Game of Thrones")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
    }

    func testStandardPatternLowercase() {
        let result = parser.parse("game.of.thrones.s01e03.mkv")
        XCTAssertEqual(result.showName, "game of thrones")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
    }

    func testStandardPatternSingleDigitSeason() {
        let result = parser.parse("Show.Name.S1E3.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
    }

    func testStandardPatternTripleDigitEpisode() {
        let result = parser.parse("One.Piece.S01E103.mkv")
        XCTAssertEqual(result.showName, "One Piece")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 103)
    }

    // MARK: - With Quality Indicators

    func testPatternWithQuality() {
        let result = parser.parse("Breaking.Bad.S01E01.1080p.BluRay.mkv")
        XCTAssertEqual(result.showName, "Breaking Bad")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 1)
        XCTAssertEqual(result.quality, "1080p")
    }

    func testPatternWith4K() {
        let result = parser.parse("Stranger.Things.S04E09.2160p.WEB-DL.mkv")
        XCTAssertEqual(result.showName, "Stranger Things")
        XCTAssertEqual(result.season, 4)
        XCTAssertEqual(result.episode, 9)
        XCTAssertEqual(result.quality, "4K")
    }

    func testPatternWith720p() {
        let result = parser.parse("The.Office.S02E05.720p.mkv")
        XCTAssertEqual(result.showName, "The Office")
        XCTAssertEqual(result.season, 2)
        XCTAssertEqual(result.episode, 5)
        XCTAssertEqual(result.quality, "720p")
    }

    // MARK: - Multi-Episode Pattern

    func testMultiEpisodeDash() {
        let result = parser.parse("Show.Name.S01E03-E04.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
        XCTAssertEqual(result.episodeEnd, 4)
        XCTAssertTrue(result.isMultiEpisode)
    }

    func testMultiEpisodeDashWithoutE() {
        let result = parser.parse("Show.Name.S01E03-04.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
        XCTAssertEqual(result.episodeEnd, 4)
    }

    func testMultiEpisodeConsecutive() {
        let result = parser.parse("Show.Name.S01E03E04.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
        XCTAssertEqual(result.episodeEnd, 4)
    }

    // MARK: - Alternative 1x03 Pattern

    func testAlternativePattern() {
        let result = parser.parse("Show.Name.1x03.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
    }

    func testAlternativePatternWithSpaces() {
        let result = parser.parse("Show Name 1x03.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
    }

    func testAlternativePatternDoubleDigit() {
        let result = parser.parse("Show.Name.10x15.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 10)
        XCTAssertEqual(result.episode, 15)
    }

    // MARK: - Verbose "Season X Episode Y" Pattern

    func testVerbosePattern() {
        let result = parser.parse("Show Name Season 1 Episode 3.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
    }

    func testVerbosePatternDots() {
        let result = parser.parse("Show.Name.Season.1.Episode.3.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
    }

    func testVerbosePatternCaseInsensitive() {
        let result = parser.parse("Show Name SEASON 2 EPISODE 10.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 2)
        XCTAssertEqual(result.episode, 10)
    }

    // MARK: - Year in Show Name

    func testShowWithYearInName() {
        let result = parser.parse("The.Flash.(2014).S01E01.mkv")
        XCTAssertEqual(result.showName, "The Flash (2014)")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 1)
    }

    func testShowWith2020InName() {
        let result = parser.parse("Show.Name.2020.S01E05.mkv")
        // Note: The year might be treated as part of the show name or parsed out
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 5)
    }

    // MARK: - Hyphenated Show Names

    func testHyphenatedShowName() {
        let result = parser.parse("Spider-Man.S01E01.mkv")
        XCTAssertEqual(result.showName, "Spider-Man")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 1)
    }

    func testXFilesStyle() {
        let result = parser.parse("The.X-Files.S01E01.mkv")
        XCTAssertEqual(result.showName, "The X-Files")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 1)
    }

    // MARK: - Underscore Separated

    func testUnderscoreSeparated() {
        let result = parser.parse("Show_Name_S01E03.mkv")
        XCTAssertEqual(result.showName, "Show Name")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 3)
    }

    // MARK: - File Extensions

    func testMKVExtension() {
        let result = parser.parse("Show.S01E01.mkv")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 1)
    }

    func testMP4Extension() {
        let result = parser.parse("Show.S01E01.mp4")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 1)
    }

    func testNoExtension() {
        let result = parser.parse("Show.S01E01")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 1)
    }

    // MARK: - Not a TV Show

    func testNotTVShow() {
        let result = parser.parse("The Matrix (1999).mkv")
        XCTAssertNil(result.season)
        XCTAssertNil(result.episode)
        XCTAssertFalse(result.isValid)
    }

    func testNotTVShowSimple() {
        let result = parser.parse("Random Movie.mkv")
        XCTAssertNil(result.season)
        XCTAssertNil(result.episode)
        XCTAssertFalse(result.isValid)
    }

    // MARK: - isTVShow Method

    func testIsTVShow() {
        XCTAssertTrue(parser.isTVShow("Show.S01E01.mkv"))
        XCTAssertTrue(parser.isTVShow("Show.1x01.mkv"))
        XCTAssertTrue(parser.isTVShow("Show Season 1 Episode 1.mkv"))
        XCTAssertFalse(parser.isTVShow("Movie (2020).mkv"))
        XCTAssertFalse(parser.isTVShow("Just a file.mkv"))
    }

    // MARK: - Formatted Episode

    func testFormattedEpisode() {
        let result = parser.parse("Show.S01E03.mkv")
        XCTAssertEqual(result.formattedEpisode, "S01E03")
    }

    func testFormattedEpisodeMulti() {
        let result = parser.parse("Show.S01E03-E04.mkv")
        XCTAssertEqual(result.formattedEpisode, "S01E03-E04")
    }

    func testFormattedEpisodeNil() {
        let result = parser.parse("Movie.mkv")
        XCTAssertNil(result.formattedEpisode)
    }

    // MARK: - Edge Cases

    func testEmptyFilename() {
        let result = parser.parse("")
        XCTAssertFalse(result.isValid)
    }

    func testJustExtension() {
        let result = parser.parse(".mkv")
        XCTAssertFalse(result.isValid)
    }

    func testReleaseGroup() {
        let result = parser.parse("Show.S01E01.720p.HDTV.x264-LOL.mkv")
        XCTAssertEqual(result.showName, "Show")
        XCTAssertEqual(result.season, 1)
        XCTAssertEqual(result.episode, 1)
        XCTAssertEqual(result.quality, "720p")
    }

    // MARK: - Equatable

    func testEquatable() {
        let result1 = TVShowParseResult(showName: "Show", season: 1, episode: 1)
        let result2 = TVShowParseResult(showName: "Show", season: 1, episode: 1)
        XCTAssertEqual(result1, result2)
    }

    func testNotEqual() {
        let result1 = TVShowParseResult(showName: "Show", season: 1, episode: 1)
        let result2 = TVShowParseResult(showName: "Show", season: 1, episode: 2)
        XCTAssertNotEqual(result1, result2)
    }
}
