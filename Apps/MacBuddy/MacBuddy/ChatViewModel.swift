import Foundation
import LLMClient
import LLMSidecarClient
import SessionStore
import SettingsStore
import Telemetry

struct ChatRow: Identifiable, Equatable {
    let id: UUID
    var role: String
    var body: String
    var isStreaming: Bool
    var status: MessageStatus

    init(id: UUID = UUID(), role: String, body: String, isStreaming: Bool = false, status: MessageStatus = .complete) {
        self.id = id
        self.role = role
        self.body = body
        self.isStreaming = isStreaming
        self.status = status
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var rows: [ChatRow] = []
    @Published var isGenerating = false
    @Published var attachedContext: String = ""
    @Published var errorBanner: String?

    private var llmSidecar: LLMSidecarClient?
    private var streamTask: Task<Void, Never>?
    private(set) var currentSessionId: UUID?
    private var sendStartedAt: CFAbsoluteTime?
    private var placeholderShownAt: CFAbsoluteTime?

    private let settingsStore = SettingsStore()

    func startNewSession(appState: AppState) {
        let session = SessionMetadata(title: "New chat", origin: .chat)
        try? appState.sessionStore.insertSession(session)
        currentSessionId = session.id
        rows = []
        appState.loadSessionMetadata()
    }

    func selectSession(_ id: UUID, appState: AppState) {
        currentSessionId = id
        let stored = (try? appState.sessionStore.fetchMessages(sessionId: id)) ?? []
        rows = stored.map {
            ChatRow(id: $0.id, role: $0.role, body: $0.body, status: $0.status)
        }
    }

    func send(text: String, appState: AppState) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGenerating else { return }

        if !settingsStore.consumeQuota() {
            errorBanner = "Monthly quota exceeded."
            return
        }

        if currentSessionId == nil {
            startNewSession(appState: appState)
        }
        guard let sessionId = currentSessionId else { return }

        errorBanner = nil
        isGenerating = true
        sendStartedAt = CFAbsoluteTimeGetCurrent()
        placeholderShownAt = CFAbsoluteTimeGetCurrent()

        let userBody = composeUserBody(prompt: trimmed)
        rows.append(ChatRow(role: "user", body: userBody))

        do {
            _ = try appState.sessionStore.insertMessage(sessionId: sessionId, role: "user", body: userBody)
            let assistantId = try appState.sessionStore.insertMessage(sessionId: sessionId, role: "assistant", body: "Thinking…")
            rows.append(ChatRow(id: assistantId, role: "assistant", body: "Thinking…", isStreaming: true))

            let title = String(trimmed.prefix(40))
            try appState.sessionStore.touchSession(id: sessionId, title: title)
            appState.loadSessionMetadata()

            streamTask = Task {
                await self.runStream(sessionId: sessionId, assistantId: assistantId, appState: appState)
            }
        } catch {
            errorBanner = "Could not save chat"
            isGenerating = false
        }
    }

    func cancel(appState: AppState) {
        streamTask?.cancel()
        Task { await llmSidecar?.cancel() }
        if let index = rows.lastIndex(where: { $0.isStreaming }) {
            rows[index].isStreaming = false
            rows[index].status = .cancelled
            if rows[index].body == "Thinking…" {
                rows[index].body = "(cancelled)"
            } else {
                rows[index].body += "\n(cancelled)"
            }
            try? appState.sessionStore.updateMessage(id: rows[index].id, body: rows[index].body, status: .cancelled)
        }
        isGenerating = false
    }

    func attachFileContents(_ text: String, maxChars: Int = 100_000) {
        let clipped = String(text.prefix(maxChars))
        if attachedContext.isEmpty {
            attachedContext = clipped
        } else {
            attachedContext += "\n\n" + clipped
        }
    }

    func pasteClipboardContext() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        attachFileContents(text)
    }

    private func composeUserBody(prompt: String) -> String {
        guard !attachedContext.isEmpty else { return prompt }
        defer { attachedContext = "" }
        return "Context:\n\(attachedContext)\n\n\(prompt)"
    }

    private func ensureLLMSidecar() async -> LLMSidecarClient {
        if let llmSidecar { return llmSidecar }
        let client = LLMSidecarClient()
        llmSidecar = client
        return client
    }

    private func runStream(sessionId: UUID, assistantId: UUID, appState: AppState) async {
        let settings = settingsStore.loadModelSettings()
        let config = LLMConfiguration(baseURL: settings.baseURL, model: settings.model)
        let apiKey = settingsStore.loadAPIKey()
        let messages = rows
            .filter { !$0.isStreaming && $0.body != "Thinking…" && $0.status != .cancelled }
            .map { ChatMessage(role: $0.role, content: $0.body) }

        do {
            let sidecar = await ensureLLMSidecar()
            let stream = await sidecar.streamCompletion(messages: messages, configuration: config, apiKey: apiKey)
            var buffer = ""
            var displayed = ""
            var lastFlush = CFAbsoluteTimeGetCurrent()
            var firstTokenRecorded = false

            for try await token in stream {
                if Task.isCancelled { break }
                buffer += token

                let now = CFAbsoluteTimeGetCurrent()
                if !firstTokenRecorded {
                    firstTokenRecorded = true
                    let ms = (now - (sendStartedAt ?? now)) * 1000
                    try? appState.telemetry.record(PerfEvent(kind: .firstToken, durationMs: ms))
                }

                if now - lastFlush >= 0.03 || buffer.count > 200 {
                    displayed += buffer
                    buffer = ""
                    lastFlush = now
                    updateAssistant(id: assistantId, body: displayed, streaming: true)
                }
            }

            displayed += buffer
            if displayed.isEmpty { displayed = "(empty response)" }
            updateAssistant(id: assistantId, body: displayed, streaming: false)
            try? appState.sessionStore.updateMessage(id: assistantId, body: displayed, status: .complete)
            isGenerating = false
        } catch LLMClientError.cancelled {
            cancel(appState: appState)
        } catch SidecarLaunchError.helperMissing {
            let message = "LLM sidecar missing. Rebuild with bash Scripts/build_app.sh"
            updateAssistant(id: assistantId, body: message, streaming: false, status: .error)
            try? appState.sessionStore.updateMessage(id: assistantId, body: message, status: .error)
            errorBanner = message
            isGenerating = false
        } catch {
            let message: String
            if case LLMClientError.httpStatus(let code, _) = error {
                message = code == 401 ? "Invalid API key" : "Request failed (\(code))"
            } else {
                message = error.localizedDescription
            }
            updateAssistant(id: assistantId, body: message, streaming: false, status: .error)
            try? appState.sessionStore.updateMessage(id: assistantId, body: message, status: .error)
            errorBanner = message
            isGenerating = false
        }
    }

    private func updateAssistant(id: UUID, body: String, streaming: Bool, status: MessageStatus = .complete) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].body = body
        rows[index].isStreaming = streaming
        rows[index].status = status
    }
}

import AppKit
