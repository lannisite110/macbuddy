import SwiftUI
import WorkSkills

struct WorkResultView: View {
    let presentation: WorkResultPresentation
    var onCopy: () -> Void
    var onReplace: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(presentation.action.menuTitle)
                .font(.headline)
            ScrollView {
                Text(presentation.resultText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("Copy") { onCopy() }
                Button("Replace Selection") { onReplace() }
                Spacer()
                Button("Done") { onDismiss() }
            }
        }
        .padding(16)
        .frame(width: 480, height: 360)
    }
}
