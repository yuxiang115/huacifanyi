import SwiftUI

/// Dictionary card for a single English word: phonetics, UK/US pronunciation, Chinese senses,
/// word forms, base form and exam tags.
struct WordCardView: View {
    let result: DictionaryResult

    private var entry: DictionaryEntry { result.entry }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headline
            pronunciation
            SenseList(senses: entry.senses)

            if !entry.forms.isEmpty {
                Text(entry.forms.map { "\($0.label) \($0.value)" }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let lemma = result.lemma {
                lemmaSection(lemma)
            }

            if !badges.isEmpty {
                HStack(spacing: 4) {
                    ForEach(badges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
        }
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.word)
                .font(.title2.weight(.semibold))
                .textSelection(.enabled)
            Spacer()
            if entry.collins > 0 {
                Text(String(repeating: "★", count: entry.collins))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help("柯林斯词频星级")
            }
        }
    }

    private var pronunciation: some View {
        HStack(spacing: 12) {
            if !entry.phonetic.isEmpty {
                Text("/\(entry.phonetic)/")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            PronounceButton(word: entry.word, label: "英", locale: "en-GB")
            PronounceButton(word: entry.word, label: "美", locale: "en-US")
        }
    }

    private func lemmaSection(_ lemma: DictionaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("原形")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(lemma.word)
                    .font(.callout.weight(.semibold))
                if !lemma.phonetic.isEmpty {
                    Text("/\(lemma.phonetic)/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            SenseList(senses: Array(lemma.senses.filter { !$0.isDomain }.prefix(3)))
        }
        .padding(.top, 2)
    }

    private var badges: [String] {
        entry.tags + (entry.isOxford3000 ? ["牛津3000"] : [])
    }
}

private struct SenseList: View {
    let senses: [DictionarySense]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(senses.enumerated()), id: \.offset) { _, sense in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let label = sense.label {
                        Text(sense.isDomain ? "[\(label)]" : label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 30, alignment: .leading)
                    }
                    Text(sense.meaning)
                        .font(sense.isDomain ? .callout : .body)
                        .foregroundStyle(sense.isDomain ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct PronounceButton: View {
    let word: String
    let label: String
    let locale: String

    var body: some View {
        Button {
            Speaker.shared.speak(word, language: locale)
        } label: {
            HStack(spacing: 2) {
                Text(label)
                Image(systemName: "speaker.wave.2")
            }
            .font(.callout)
        }
        .buttonStyle(.borderless)
        .help(label == "英" ? "英式发音" : "美式发音")
    }
}
