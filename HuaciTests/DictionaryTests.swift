import XCTest

final class DictionaryFormatTests: XCTestCase {
    func testSensesSplitPartOfSpeechAndDomain() {
        let senses = DictionaryFormat.senses(from: "adv. 最后, 终于\n[医] 苹果\ngo的过去式\nvt. 给...浇水")
        XCTAssertEqual(senses, [
            DictionarySense(label: "adv.", meaning: "最后, 终于", isDomain: false),
            DictionarySense(label: "医", meaning: "苹果", isDomain: true),
            DictionarySense(label: nil, meaning: "go的过去式", isDomain: false),
            DictionarySense(label: "vt.", meaning: "给...浇水", isDomain: false),
        ])
    }

    func testExchangeFormsInFixedOrder() {
        let (forms, lemma) = DictionaryFormat.exchange("i:going/p:went/d:gone/3:goes", word: "go")
        XCTAssertEqual(forms.map(\.label), ["过去式", "过去分词", "现在分词", "第三人称单数"])
        XCTAssertEqual(forms.map(\.value), ["went", "gone", "going", "goes"])
        XCTAssertNil(lemma)
    }

    func testExchangeLemmaOfAnInflection() {
        let (forms, lemma) = DictionaryFormat.exchange("0:go/1:p", word: "went")
        XCTAssertTrue(forms.isEmpty)
        XCTAssertEqual(lemma, "go")
    }

    func testTagsAreNamedAndOrdered() {
        XCTAssertEqual(DictionaryFormat.tags("ky cet4 gk zk"), ["中考", "高考", "四级", "考研"])
        XCTAssertEqual(DictionaryFormat.tags(""), [])
    }

    func testLookupKeyAcceptsShortEnglishOnly() {
        XCTAssertEqual(DictionaryFormat.lookupKey(for: "  Finally, "), "Finally")
        XCTAssertEqual(DictionaryFormat.lookupKey(for: "give   up"), "give up")
        XCTAssertEqual(DictionaryFormat.lookupKey(for: "don’t"), "don't")
        XCTAssertEqual(DictionaryFormat.lookupKey(for: "e-mail"), "e-mail")
        XCTAssertNil(DictionaryFormat.lookupKey(for: "今天"))
        XCTAssertNil(DictionaryFormat.lookupKey(for: "123"))
        XCTAssertNil(DictionaryFormat.lookupKey(for: "this is a sentence"))
        XCTAssertNil(DictionaryFormat.lookupKey(for: "café"))
    }
}

final class DictionaryStoreTests: XCTestCase {
    private var store: DictionaryStore!

    override func setUpWithError() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Dictionary", withExtension: "sqlite"))
        store = try DictionaryStore(url: url)
    }

    func testLooksUpPhoneticsSensesAndTags() throws {
        let entry = try XCTUnwrap(store.lookup("Finally,")?.entry)
        XCTAssertEqual(entry.word, "finally")
        XCTAssertEqual(entry.phonetic, "ˈfaɪnəli")
        XCTAssertEqual(entry.senses.first?.label, "adv.")
        XCTAssertTrue(entry.senses.first?.meaning.contains("最后") ?? false)
        XCTAssertTrue(entry.tags.contains("四级"))
    }

    func testInflectionBringsItsBaseForm() throws {
        let result = try XCTUnwrap(store.lookup("went"))
        XCTAssertEqual(result.entry.lemma, "go")
        XCTAssertEqual(result.lemma?.word, "go")
        XCTAssertEqual(result.lemma?.forms.first { $0.label == "过去式" }?.value, "went")
    }

    func testPhoneticsAreModernIPA() throws {
        // Old ECDICT notation: ðєə / bɒi / 'wɒːtə / iˈ^zæktli
        XCTAssertEqual(store.entry(for: "there")?.phonetic, "ðeə")
        XCTAssertEqual(store.entry(for: "boy")?.phonetic, "bɔɪ")
        XCTAssertEqual(store.entry(for: "water")?.phonetic, "ˈwɔːtə")
        XCTAssertEqual(store.entry(for: "exactly")?.phonetic.contains("^"), false)
    }

    func testNonEnglishOrUnknownTextHasNoEntry() {
        XCTAssertNil(store.lookup("今天天气很好"))
        XCTAssertNil(store.lookup("qwzxkj"))
        XCTAssertNil(store.lookup("The quick brown fox jumps"))
    }
}
