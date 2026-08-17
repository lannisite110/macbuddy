import SwiftUI
import UniformTypeIdentifiers

struct ChatPanelView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var chat = ChatViewModel()
    @ObservedObject private var work = WorkCoordinator.shared
    @FocusState private var composerFocused: Bool
    @State private var draft = ""
    let onComposerReady: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SessionListView(onSelect: { id in
                chat.selectSession(id, appState: appState)
            }, onNewChat: {
                chat.startNewSession(appState: appState)
            })
            .frame(height: 100)

            Divider()

            if let banner = chat.errorBanner ?? work.errorMessage {
                Text(banner)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }

            if work.isRunning {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Running work action…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
            }

            if !chat.attachedContext.isEmpty {
                Text("Context attached (\(chat.attachedContext.count) chars)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }

            MessageListView(rows: chat.rows)
                .frame(maxHeight: .infinity)

            Divider()

            HStack(spacing: 8) {
                if chat.isGenerating {
                    Button("Cancel") {
                        chat.cancel(appState: appState)
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                } else {
                    Button("Paste context") {
                        chat.pasteClipboardContext()
                    }
                    Button("New") {
                        chat.startNewSession(appState: appState)
                    }
                }
                Spacer()
                Button("Send") {
                    send()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(chat.isGenerating || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            TextEditor(text: $draft)
                .font(.body)
                .focused($composerFocused)
                .frame(height: 88)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .accessibilityIdentifier("composer")
                .onDrop(of: [.fileURL, .plainText], isTargeted: nil) { providers in
                    handleDrop(providers)
                }
        }
        .sheet(item: $work.activeResult) { result in
            WorkResultView(
                presentation: result,
                onCopy: { work.copyResult(result.resultText) },
                onReplace: { work.replaceSelection(with: result.resultText) },
                onDismiss: { work.activeResult = nil }
            )
        }
        .onAppear {
            LaunchTiming.markComposerReady(telemetry: appState.telemetry)
            onComposerReady()
            composerFocused = true
            if chat.currentSessionId == nil, let first = appState.sessions.first {
                chat.selectSession(first.id, appState: appState)
            }
        }
    }

    private func send() {
        let text = draft
        draft = ""
        chat.send(text: text, appState: appState)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard
                        let data = item as? Data,
                        let url = URL(dataRepresentation: data, relativeTo: nil),
                        let text = try? String(contentsOf: url, encoding: .utf8)
                    else { return }
                    Task { @MainActor in
                        chat.attachFileContents(text)
                    }
                }
                return true
            }
        }
        return false
    }
}
