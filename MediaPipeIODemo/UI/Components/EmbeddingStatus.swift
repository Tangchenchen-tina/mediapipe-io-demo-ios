import SwiftUI

/// Snapshot of an in-flight (re-)embedding run — `itemsPerSecond` is the running average since it started.
struct EmbeddingProgress: Equatable {
    let done: Int
    let total: Int
    let itemsPerSecond: Double
}

/// Small filled/outline dot used on list rows and message bubbles to mark embedded vs
/// not-yet-embedded content.
struct EmbeddingStatusIcon: View {
    let isIndexed: Bool

    var body: some View {
        Image(systemName: isIndexed ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isIndexed ? Color.accentColor : Color.secondary.opacity(0.4))
            .font(.system(size: 15))
            .accessibilityLabel(isIndexed ? "Embedded" : "Not embedded yet")
    }
}

/// Progress bar + "N/M (X.X items/sec)" readout for an active re-embed run.
struct EmbeddingProgressView: View {
    let progress: EmbeddingProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: progress.total > 0 ? Double(progress.done) / Double(progress.total) : 0)
            Text("Embedding… \(progress.done)/\(progress.total) (\(String(format: "%.1f", progress.itemsPerSecond)) items/sec)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// "N/M <items> embedded" + "Re-embed all" row, swapping to `EmbeddingProgressView` while a run
/// is active — shared by all three sections' list screens (Chats, Archive, Email).
struct EmbeddingStatusBar: View {
    let itemLabel: String
    let embeddedCount: Int
    let totalCount: Int
    let progress: EmbeddingProgress?
    let onReembedAll: () -> Void

    var body: some View {
        Group {
            if let progress {
                EmbeddingProgressView(progress: progress)
            } else {
                HStack {
                    Text("\(embeddedCount)/\(totalCount) \(itemLabel) embedded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Re-embed all", action: onReembedAll)
                        .font(.caption)
                        .disabled(totalCount == 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
