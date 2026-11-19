import XCTest

final class LLMStreamDecoderTests: XCTestCase {
    func testDataLinePayload() {
        XCTAssertEqual(LLMStreamDecoder.payload(ofLine: "data: {\"a\":1}"), "{\"a\":1}")
        XCTAssertEqual(LLMStreamDecoder.payload(ofLine: "data:[DONE]"), "[DONE]")
        XCTAssertNil(LLMStreamDecoder.payload(ofLine: "event: ping"))
        XCTAssertNil(LLMStreamDecoder.payload(ofLine: ": keep-alive"))
        XCTAssertNil(LLMStreamDecoder.payload(ofLine: ""))
    }

    // MARK: OpenAI-compatible

    func testOpenAITextDelta() {
        let payload = #"{"choices":[{"index":0,"delta":{"content":"你好"}}]}"#
        XCTAssertEqual(LLMStreamDecoder.decode(payload, format: .openAI), .text("你好"))
    }

    func testOpenAIRoleOnlyAndReasoningDeltasAreSkipped() {
        XCTAssertNil(LLMStreamDecoder.decode(#"{"choices":[{"delta":{"role":"assistant"}}]}"#, format: .openAI))
        XCTAssertNil(LLMStreamDecoder.decode(#"{"choices":[{"delta":{"reasoning_content":"hmm"}}]}"#, format: .openAI))
        XCTAssertNil(LLMStreamDecoder.decode(#"{"choices":[{"delta":{"content":""}}]}"#, format: .openAI))
    }

    func testOpenAIDoneAndError() {
        XCTAssertEqual(LLMStreamDecoder.decode("[DONE]", format: .openAI), .done)
        XCTAssertEqual(
            LLMStreamDecoder.decode(#"{"error":{"message":"invalid api key"}}"#, format: .openAI),
            .failure("invalid api key")
        )
    }

    // MARK: Anthropic

    func testAnthropicTextDelta() {
        let payload = #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}"#
        XCTAssertEqual(LLMStreamDecoder.decode(payload, format: .anthropic), .text("Hello"))
    }

    func testAnthropicThinkingAndPingAreSkipped() {
        let thinking = #"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"..."}}"#
        XCTAssertNil(LLMStreamDecoder.decode(thinking, format: .anthropic))
        XCTAssertNil(LLMStreamDecoder.decode(#"{"type":"ping"}"#, format: .anthropic))
        XCTAssertNil(LLMStreamDecoder.decode(#"{"type":"message_delta","delta":{"stop_reason":"end_turn"}}"#, format: .anthropic))
    }

    func testAnthropicStopRefusalAndError() {
        XCTAssertEqual(LLMStreamDecoder.decode(#"{"type":"message_stop"}"#, format: .anthropic), .done)
        XCTAssertEqual(
            LLMStreamDecoder.decode(#"{"type":"message_delta","delta":{"stop_reason":"refusal"}}"#, format: .anthropic),
            .failure("模型拒绝翻译这段内容。")
        )
        XCTAssertEqual(
            LLMStreamDecoder.decode(#"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#, format: .anthropic),
            .failure("Overloaded")
        )
    }

    func testMalformedPayloadIsIgnored() {
        XCTAssertNil(LLMStreamDecoder.decode("not json", format: .openAI))
        XCTAssertNil(LLMStreamDecoder.decode("not json", format: .anthropic))
    }
}
