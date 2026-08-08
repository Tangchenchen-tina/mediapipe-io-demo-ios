import SwiftUI

/// The "message bubble like pop out box" — a floating card that fills in as MediaPipe streams a
/// summary, rather than appearing all at once. Used by both the Archive document viewer (floating
/// button, bottom-right) and the Email detail screen. Fixed max height with its own internal
/// scroll, so a long summary doesn't grow the bubble to cover the whole screen — the surrounding
/// app content stays put and scrollable on its own.
struct SummaryBubble: View {
    let text: String
    let isStreaming: Bool
    let error: String?
    let mode: SummaryMode
    let onSelectMode: (SummaryMode) -> Void
    let onClose: () -> Void
    let onResetEngine: () -> Void

    private static let maxHeight: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Summary", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                modeButton(title: "TL;DR", isSelected: mode == .tldr, target: .tldr)
                modeButton(title: "Keypoints", isSelected: mode == .keyPoints, target: .keyPoints)
                Spacer()
                // Manual escape hatch: some inputs have been observed to leave the on-device
                // engine unusable for every call after the one that failed, not just that one —
                // this recreates it on demand rather than waiting for the next error to trigger
                // the automatic reset.
                Button {
                    onResetEngine()
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset engine")
            }

            if let error {
                Text("Couldn't summarize: \(error)")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else {
                ScrollView {
                    Text(text.isEmpty ? " " : text)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: Self.maxHeight)

                if isStreaming {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("Generating…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 320, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8, y: 2)
    }

    // A plain-Button pair rather than a `Picker`/`Binding` — constructing a `Binding` from a
    // closure captured across this view boundary tripped a Swift 6 Sendable-closure error, and
    // this sidesteps it entirely while still looking like a segmented control.
    @ViewBuilder
    private func modeButton(title: String, isSelected: Bool, target: SummaryMode) -> some View {
        Button {
            onSelectMode(target)
        } label: {
            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isStreaming)
    }
}
