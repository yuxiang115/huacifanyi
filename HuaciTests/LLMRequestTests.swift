import XCTest

final class LLMRequestTests: XCTestCase {
    private func config(_ format: LLMFormat, base: String, key: String = "", effort: String = "") -> LLMConfig {
        LLMConfig(format: format, baseURL: base, model: "test-model", apiKey: key, effort: effort)
    }

    private func endpoint(_ format: LLMFormat, _ base: String) throws -> String {
        try LLMRequestBuilder.endpoint(for: config(format, base: base)).absoluteString
    }

    private func body(of request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: Endpoints

    func testOpenAIEndpointAppendsChatCompletions() throws {
        XCTAssertEqual(try endpoint(.openAI, "https://api.deepseek.com/v1"), "https://api.deepseek.com/v1/chat/completions")
        XCTAssertEqual(try endpoint(.openAI, " http://localhost:11434/v1/ "), "http://localhost:11434/v1/chat/completions")
        XCTAssertEqual(try endpoint(.openAI, "https://x.test/v1/chat/completions"), "https://x.test/v1/chat/completions")
    }

    func testAnthropicEndpointAppendsMessages() throws {
        XCTAssertEqual(try endpoint(.anthropic, "https://api.anthropic.com"), "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(try endpoint(.anthropic, "https://proxy.test/v1"), "https://proxy.test/v1/messages")
        XCTAssertEqual(try endpoint(.anthropic, "https://proxy.test/v1/messages/"), "https://proxy.test/v1/messages")
    }

    func testEndpointWithoutSchemeIsRejected() {
        XCTAssertThrowsError(try endpoint(.openAI, "api.example.com/v1"))
        XCTAssertThrowsError(try endpoint(.openAI, "ftp://example.com/v1"))
    }

    func testIncompleteConfigIsRejected() {
        let missingModel = LLMConfig(format: .openAI, baseURL: "https://x.test/v1", model: " ", apiKey: "")
        XCTAssertThrowsError(
            try LLMRequestBuilder.makeRequest(config: missingModel, text: "hi", sourceName: nil, targetName: "English")
        ) { error in
            XCTAssertEqual(error as? LLMRequestError, .notConfigured)
        }
    }

    // MARK: OpenAI-compatible

    func testOpenAIRequestUsesBearerKeyAndStreams() throws {
        let request = try LLMRequestBuilder.makeRequest(
            config: config(.openAI, base: "https://x.test/v1", key: "sk-test"),
            text: "你好",
            sourceName: "Chinese",
            targetName: "English"
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")

        let body = try body(of: request)
        XCTAssertEqual(body["model"] as? String, "test-model")
        XCTAssertEqual(body["stream"] as? Bool, true)
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(messages.map { $0["role"] }, ["system", "user"])
        XCTAssertEqual(messages.last?["content"], "你好")
        XCTAssertTrue(messages.first?["content"]?.contains("from Chinese into English") ?? false)
    }

    func testOpenAIRequestWithoutKeyHasNoAuthorization() throws {
        let request = try LLMRequestBuilder.makeRequest(
            config: config(.openAI, base: "http://localhost:11434/v1"),
            text: "hi",
            sourceName: nil,
            targetName: "Chinese"
        )
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    // MARK: Anthropic

    func testAnthropicRequestHeadersAndBody() throws {
        let request = try LLMRequestBuilder.makeRequest(
            config: config(.anthropic, base: "https://api.anthropic.com", key: "sk-ant-test"),
            text: "hello",
            sourceName: "English",
            targetName: "Chinese"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), LLMRequestBuilder.anthropicVersion)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

        let body = try body(of: request)
        XCTAssertEqual(body["model"] as? String, "test-model")
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["max_tokens"] as? Int, LLMRequestBuilder.maxTokens)
        XCTAssertNotNil(body["system"] as? String)
        XCTAssertNil(body["output_config"])
    }

    func testAnthropicEffortIsSentOnlyWhenSet() throws {
        let request = try LLMRequestBuilder.makeRequest(
            config: config(.anthropic, base: "https://api.anthropic.com", effort: "low"),
            text: "hello",
            sourceName: nil,
            targetName: "Chinese"
        )
        let body = try body(of: request)
        let outputConfig = try XCTUnwrap(body["output_config"] as? [String: String])
        XCTAssertEqual(outputConfig["effort"], "low")
    }
}
