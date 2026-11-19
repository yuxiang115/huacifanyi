import Foundation
import SQLite3

/// Read-only lookups in the bundled ECDICT subset (Resources/Dictionary.sqlite,
/// built by scripts/build_dictionary.py). Lookups hit an index and take well under a millisecond.
final class DictionaryStore {
    enum StoreError: Error {
        case cannotOpen(String)
    }

    /// nil if the database is missing from the bundle.
    static let shared: DictionaryStore? = {
        guard let url = Bundle.main.url(forResource: "Dictionary", withExtension: "sqlite") else { return nil }
        return try? DictionaryStore(url: url)
    }()

    private var db: OpaquePointer?
    private let lock = NSLock()

    init(url: URL) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(handle)
            throw StoreError.cannotOpen(message)
        }
        db = handle
    }

    deinit {
        sqlite3_close(db)
    }

    /// Looks up a selection; returns nil unless it is a short English word/phrase in the dictionary.
    func lookup(_ text: String) -> DictionaryResult? {
        guard let key = DictionaryFormat.lookupKey(for: text), let entry = entry(for: key) else { return nil }
        let lemma = entry.lemma.flatMap { self.entry(for: $0) }
        return DictionaryResult(entry: entry, lemma: lemma)
    }

    func entry(for word: String) -> DictionaryEntry? {
        lock.lock()
        defer { lock.unlock() }

        // Exact case first ("US" vs "us"), then the most frequent.
        let sql = """
            SELECT word, phonetic, translation, definition, exchange, tag, collins, oxford
            FROM entries WHERE word = ?1 COLLATE NOCASE
            ORDER BY (word = ?1) DESC, (frq = 0), frq
            LIMIT 1
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, word, -1, transient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }

        func text(_ column: Int32) -> String {
            sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
        }

        let headword = text(0)
        let (forms, lemma) = DictionaryFormat.exchange(text(4), word: headword)
        return DictionaryEntry(
            word: headword,
            phonetic: text(1),
            senses: DictionaryFormat.senses(from: text(2)),
            definitions: text(3).split(separator: "\n").map(String.init),
            forms: forms,
            lemma: lemma,
            tags: DictionaryFormat.tags(text(5)),
            collins: Int(sqlite3_column_int(statement, 6)),
            isOxford3000: sqlite3_column_int(statement, 7) != 0
        )
    }
}
