import CodeEngine
import SwiftUI

struct DiffPreviewView: View {
    let preview: PatchPreview
    var onApply: () -> Void
    var onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patch Preview")
                .font(.headline)
            Text(preview.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(preview.changes) { change in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(change.relativePath)
                                .font(.subheadline.weight(.semibold))
                            Text(change.unifiedDiff)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            HStack {
                Button("Apply") { onApply() }
                    .keyboardShortcut(.defaultAction)
                Button("Decline") { onDecline() }
            }
        }
        .padding(16)
        .frame(width: 640, height: 480)
    }
}

struct GitOutputView: View {
    let title: String
    let text: String
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ScrollView {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("Done") { onDismiss() }
        }
        .padding(16)
        .frame(width: 560, height: 400)
    }
}
