import Foundation

enum LLMError: LocalizedError {
    case badResponse
    case http(Int, String)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .badResponse:
            "服务器返回了无法识别的响应。"
        case .http(let status, let body):
            "HTTP \(status)：\(Self.message(fromBody: body))"
        case .api(let message):
            message
        }
    }

    /// Pulls `error.message` out of a JSON error body (both formats use it), else the raw text.
    private static func message(fromBody body: String) -> String {
        if let data = body.data(using: .utf8),
           let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        let text = body.trimmed
        return text.isEmpty ? "（没有返回内容）" : String(text.prefix(300))
    }
}

enum LLMTranslator {
    /// Streams the translation as text chunks.
    static func stream(
        text: String,
        plan: LanguagePlan,
        config: LLMConfig,
        session: URLSession = .shared
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try LLMRequestBuilder.makeRequest(
                        config: config,
                        text: text,
                        sourceName: plan.source.map(LanguageDirection.englishName),
                        targetName: LanguageDirection.englishName(plan.target)
                    )
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw LLMError.badResponse }

                    guard (200..<300).contains(http.statusCode) else {
                        var body = ""
                        for try await line in bytes.lines {
                            body += line
                            if body.count > 4000 { break }
                        }
                        throw LLMError.http(http.statusCode, body)
                    }

                    for try await line in bytes.lines {
                        guard let payload = LLMStreamDecoder.payload(ofLine: line),
                              let event = LLMStreamDecoder.decode(payload, format: config.format)
                        else { continue }

                        switch event {
                        case .text(let chunk):
                            continuation.yield(chunk)
                        case .done:
                            continuation.finish()
                            return
                        case .failure(let message):
                            throw LLMError.api(message)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
