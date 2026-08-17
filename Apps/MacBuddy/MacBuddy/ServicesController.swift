import AppKit
import WorkSkills

@MainActor
final class ServicesController: NSObject {
    static let shared = ServicesController()

    @objc func summarizeText(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handle(pboard: pboard, action: .summarize)
    }

    @objc func rewriteText(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handle(pboard: pboard, action: .rewrite)
    }

    @objc func meetingNotesText(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handle(pboard: pboard, action: .meetingNotes)
    }

    private func handle(pboard: NSPasteboard, action: WorkAction) {
        NSApp.activate(ignoringOtherApps: true)
        ChatWindowController.shared.show(focusComposer: {})

        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first {
            Task { @MainActor in
                do {
                    let text = try FileTextReader.readText(from: url)
                    await WorkCoordinator.shared.perform(action: action, input: text)
                } catch {
                    WorkCoordinator.shared.errorMessage = error.localizedDescription
                }
            }
            return
        }
        guard let text = pboard.string(forType: .string), !text.isEmpty else { return }
        Task { @MainActor in
            await WorkCoordinator.shared.perform(action: action, input: text)
        }
    }
}
