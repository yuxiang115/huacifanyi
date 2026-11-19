import Foundation

enum LLMStreamEvent: Equatable {
    case text(String)
    case done
    case failure(String)
}

/// Turns server-sent-event lines from either wire format into text chunks.
enum LLMStreamDecoder {
    /// The payload of an SSE `data:` line, or nil for any other line (`event:`, comments, blanks).
    static func payload(ofLine line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let rest = line.dropFirst(5)
        return String(rest.first == " " ? rest.dropFirst() : rest)
    }

    /// nil means "nothing to show for this event" (role headers, pings, thinking, usage…).
    static func decode(_ payload: String, format: LLMFormat) -> LLMStreamEvent? {
        switch format {
        case .openAI: decodeOpenAI(payload)
        case .anthropic: decodeAnthropic(payload)
        }
    }

    private static func decodeOpenAI(_ payload: String) -> LLMStreamEvent? {
        if payload.trimmed == "[DONE]" { return .done }
        guard let object = jsonObject(payload) else { return nil }

        if let error = object["error"] as? [String: Any] {
            return .failure(error["message"] as? String ?? "接口返回了错误。")
        }
        guard let choices = object["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String,
              !content.isEmpty
        else { return nil }
        return .text(content)
    }

    private static func decodeAnthropic(_ payload: String) -> LLMStreamEvent? {
        guard let object = jsonObject(payload), let type = object["type"] as? String else { return nil }

        switch type {
        case "content_block_delta":
            // Only text deltas; thinking and tool-input deltas are skipped.
            guard let delta = object["delta"] as? [String: Any],
                  delta["type"] as? String == "text_delta",
                  let text = delta["text"] as? String
            else { return nil }
            return .text(text)
        case "message_delta":
            if let delta = object["delta"] as? [String: Any], delta["stop_reason"] as? String == "refusal" {
                return .failure("模型拒绝翻译这段内容。")
            }
            return nil
        case "message_stop":
            return .done
        case "error":
            let error = object["error"] as? [String: Any]
            return .failure(error?["message"] as? String ?? "接口返回了错误。")
        default:
            return nil
        }
    }

    private static func jsonObject(_ payload: String) -> [String: Any]? {
        guard let data = payload.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
