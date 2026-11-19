import XCTest

final class LanguageDirectionTests: XCTestCase {
    func testChineseGoesToSecondaryLanguage() {
        let plan = LanguageDirection.plan(for: "今天天气很好，我们去公园散步吧。", primary: "zh-Hans", secondary: "en")
        XCTAssertEqual(plan.source, "zh-Hans")
        XCTAssertEqual(plan.target, "en")
    }

    func testEnglishGoesToPrimaryLanguage() {
        let plan = LanguageDirection.plan(
            for: "The quick brown fox jumps over the lazy dog.",
            primary: "zh-Hans",
            secondary: "en"
        )
        XCTAssertEqual(plan.source, "en")
        XCTAssertEqual(plan.target, "zh-Hans")
    }

    func testOtherLanguagesGoToPrimaryLanguage() {
        let plan = LanguageDirection.plan(
            for: "Bonjour tout le monde, comment allez-vous aujourd'hui ?",
            primary: "zh-Hans",
            secondary: "en"
        )
        XCTAssertEqual(plan.source, "fr")
        XCTAssertEqual(plan.target, "zh-Hans")
    }

    func testAmbiguousShortWordsFallBackToTheUsersLanguages() {
        // Without the fallback these come back as Turkish and Polish.
        XCTAssertEqual(LanguageDirection.plan(for: "apple", primary: "zh-Hans", secondary: "en").source, "en")
        XCTAssertEqual(LanguageDirection.plan(for: "ok", primary: "zh-Hans", secondary: "en").source, "en")
        XCTAssertEqual(LanguageDirection.plan(for: "finally", primary: "zh-Hans", secondary: "en").source, "en")
    }

    func testConfidentOtherLanguagesAreKept() {
        XCTAssertEqual(LanguageDirection.plan(for: "Guten Morgen", primary: "zh-Hans", secondary: "en").source, "de")
        XCTAssertEqual(LanguageDirection.plan(for: "ありがとうございます", primary: "zh-Hans", secondary: "en").source, "ja")
    }

    func testScriptVariantsCountAsTheSameLanguage() {
        XCTAssertTrue(LanguageDirection.isSameLanguage("zh-Hans", "zh-Hant"))
        XCTAssertTrue(LanguageDirection.isSameLanguage("en", "en"))
        XCTAssertFalse(LanguageDirection.isSameLanguage("en", "zh-Hans"))
    }

    func testEnglishNameForPrompts() {
        XCTAssertEqual(LanguageDirection.englishName("en"), "English")
        XCTAssertTrue(LanguageDirection.englishName("zh-Hans").hasPrefix("Chinese"))
    }
}
