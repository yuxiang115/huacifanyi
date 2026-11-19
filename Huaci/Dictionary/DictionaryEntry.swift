import Foundation

/// One line of the Chinese definitions, e.g. "adv. 最后, 终于" or "[医] 苹果".
struct DictionarySense: Equatable {
    /// "adv.", "n.", "vt." …, or a domain such as "医" / "网络".
    var label: String?
    var meaning: String
    /// Domain lines ("[医] …") are secondary.
    var isDomain: Bool
}

struct DictionaryForm: Equatable {
    var label: String
    var value: String
}

struct DictionaryEntry: Equatable {
    var word: String
    /// Modern IPA without slashes, e.g. "ˈfaɪnəli". May be empty.
    var phonetic: String
    var senses: [DictionarySense]
    var definitions: [String]
    var forms: [DictionaryForm]
    /// Base form when this entry is an inflection ("went" → "go").
    var lemma: String?
    var tags: [String]
    var collins: Int
    var isOxford3000: Bool
}

/// The entry for the looked-up word, plus its base form when it is an inflection.
struct DictionaryResult: Equatable {
    var entry: DictionaryEntry
    var lemma: DictionaryEntry?
}

/// Parsing of ECDICT's compact fields.
enum DictionaryFormat {
    static func senses(from translation: String) -> [DictionarySense] {
        translation.split(separator: "\n").compactMap { rawLine in
            let line = String(rawLine).trimmed
            guard !line.isEmpty else { return nil }

            // "[医] 苹果"
            if line.hasPrefix("["), let close = line.firstIndex(of: "]") {
                let domain = String(line[line.index(after: line.startIndex)..<close])
                let meaning = String(line[line.index(after: close)...]).trimmed
                return DictionarySense(label: domain, meaning: meaning, isDomain: true)
            }
            // "adv. 最后, 终于" / "vt. 给...浇水"
            if let dot = line.firstIndex(of: "."),
               line[..<dot].count <= 5,
               line[..<dot].allSatisfy({ $0.isASCII && $0.isLetter }) {
                let label = String(line[...dot])
                let meaning = String(line[line.index(after: dot)...]).trimmed
                return DictionarySense(label: label, meaning: meaning, isDomain: false)
            }
            return DictionarySense(label: nil, meaning: line, isDomain: false)
        }
    }

    private static let formLabels: [(key: String, label: String)] = [
        ("s", "复数"), ("p", "过去式"), ("d", "过去分词"), ("i", "现在分词"),
        ("3", "第三人称单数"), ("r", "比较级"), ("t", "最高级"),
    ]

    /// "s:apples/p:went/0:go/1:p" → forms + lemma.
    static func exchange(_ field: String, word: String) -> (forms: [DictionaryForm], lemma: String?) {
        var values: [String: String] = [:]
        for part in field.split(separator: "/") {
            let pieces = part.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2 else { continue }
            values[String(pieces[0])] = String(pieces[1])
        }
        let forms = formLabels.compactMap { key, label -> DictionaryForm? in
            guard let value = values[key], value.caseInsensitiveCompare(word) != .orderedSame else { return nil }
            return DictionaryForm(label: label, value: value)
        }
        let lemma = values["0"].flatMap { $0.caseInsensitiveCompare(word) == .orderedSame ? nil : $0 }
        return (forms, lemma)
    }

    private static let tagNames: [String: String] = [
        "zk": "中考", "gk": "高考", "cet4": "四级", "cet6": "六级", "ky": "考研",
        "toefl": "托福", "ielts": "雅思", "gre": "GRE",
    ]
    private static let tagOrder = ["zk", "gk", "cet4", "cet6", "ky", "ielts", "toefl", "gre"]

    static func tags(_ field: String) -> [String] {
        let present = Set(field.split(separator: " ").map(String.init))
        return tagOrder.filter(present.contains).compactMap { tagNames[$0] }
    }

    /// The text to look up when the selection is a short English word or phrase; nil otherwise.
    static func lookupKey(for text: String) -> String? {
        let edgePunctuation = CharacterSet(charactersIn: ".,;:!?\"“”‘’()[]{}<>")
        let cleaned = text.trimmed
            .trimmingCharacters(in: edgePunctuation)
            .replacingOccurrences(of: "’", with: "'")
            .trimmed
        guard !cleaned.isEmpty, cleaned.count <= 40 else { return nil }

        let words = cleaned.split(whereSeparator: \.isWhitespace)
        guard words.count <= 3 else { return nil }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-'")
        guard words.allSatisfy({ $0.unicodeScalars.allSatisfy(allowed.contains) }),
              cleaned.contains(where: \.isLetter)
        else { return nil }
        return words.joined(separator: " ")
    }
}
