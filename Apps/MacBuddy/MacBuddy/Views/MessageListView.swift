import SwiftUI

struct MessageListView: View {
    let rows: [ChatRow]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(rows) { row in
                        MessageBubble(row: row)
                            .id(row.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: rows.count) { _, _ in
                if let last = rows.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

private struct MessageBubble: View {
    let row: ChatRow

    var body: some View {
        HStack {
            if row.role == "assistant" { Spacer(minLength: 24) }
            VStack(alignment: .leading, spacing: 4) {
                Text(row.role == "user" ? "You" : "MacBuddy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(row.body)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(row.role == "user" ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                if row.status == .cancelled {
                    Text("Cancelled")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if row.isStreaming {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if row.role == "user" { Spacer(minLength: 24) }
        }
    }
}
