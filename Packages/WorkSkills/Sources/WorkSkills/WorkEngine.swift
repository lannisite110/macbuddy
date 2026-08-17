import Foundation
import LLMClient

public actor WorkEngine {
    private var llmClient: LLMClient?

    public init() {}

    public func run(
        action: WorkAction,
        input: String,
        configuration: LLMConfiguration,
        apiKey: String?
    ) async throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WorkSkillsError.emptyInput }

        let client = try await client(configuration: configuration, apiKey: apiKey)
        let messages = [
            ChatMessage(role: "system", content: WorkPrompts.systemPrompt(for: action)),
            ChatMessage(role: "user", content: WorkPrompts.userPrompt(for: action, text: trimmed)),
        ]

        let stream = await client.streamCompletion(messages: messages)
        var output = ""
        for try await token in stream {
            output += token
        }
        let result = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw LLMClientError.emptyResponse }
        return result
    }

    public func cancel() async {
        await llmClient?.cancel()
    }

    private func client(configuration: LLMConfiguration, apiKey: String?) async throws -> LLMClient {
        if let llmClient { return llmClient }
        let client = try LLMClient(configuration: configuration, apiKey: apiKey)
        llmClient = client
        return client
    }
}
