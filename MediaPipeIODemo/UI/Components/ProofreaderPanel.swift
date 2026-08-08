import SwiftUI

/// "📝 Proofreader" card — renders `computeWordDiff` as an inline diff (strikethrough removals,
/// colored additions) once a corrected version exists. Mirrors the Android sibling app's
/// `ProofreaderPanel`.
struct ProofreaderPanel: View {
    let originalText: String
    let correctedText: String?
    let isLoading: Bool
    let onProofread: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📝 Proofreader")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            HStack(spacing: 12) {
                Button(correctedText == nil ? "Proofread" : "Proofread again", action: onProofread)
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                if isLoading {
                    ProgressView()
                }
            }

            if let correctedText {
                diffText(original: originalText, corrected: correctedText)
                    .font(.body)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func diffText(original: String, corrected: String) -> Text {
        computeWordDiff(original: original, corrected: corrected).reduce(Text("")) { acc, segment in
            switch segment {
            case .unchanged(let text):
                return acc + Text(text)
            case .removed(let text):
                return acc + Text(text).strikethrough().foregroundColor(.red)
            case .added(let text):
                return acc + Text(text).foregroundColor(.green)
            }
        }
    }
}
