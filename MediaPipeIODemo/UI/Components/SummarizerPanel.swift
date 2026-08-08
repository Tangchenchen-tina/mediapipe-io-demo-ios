import SwiftUI

enum SummarizerDisplayMode: String, CaseIterable, Identifiable {
    case tldr = "TL;DR"
    case keyPoints = "Keypoints"
    case rawText = "Raw Text"

    var id: String { rawValue }
}

/// Shared "✨ <title>" card used by all three sections' summarize actions — Chats (History
/// Summarizer), Archive (per-page summarizer), Email (persisted summary). `onClear` is nil for
/// call sites whose result is persisted server-side rather than ephemeral view state (mirrors the
/// Android sibling app's `SummarizerPanel`, including that same nullable-`onClear` distinction).
struct SummarizerPanel: View {
    let title: String
    let rawText: String
    let includeRawTextMode: Bool
    let isLoading: Bool
    let result: String?
    let onGenerate: (SummaryMode) -> Void
    let onClear: (() -> Void)?

    @State private var mode: SummarizerDisplayMode = .tldr

    private var availableModes: [SummarizerDisplayMode] {
        includeRawTextMode ? SummarizerDisplayMode.allCases : [.tldr, .keyPoints]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("✨ \(title)")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            Picker("Mode", selection: $mode) {
                ForEach(availableModes) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button("Summarize Now") {
                    switch mode {
                    case .tldr: onGenerate(.tldr)
                    case .keyPoints: onGenerate(.keyPoints)
                    case .rawText: break // handled below, no engine call needed
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || mode == .rawText)

                if isLoading {
                    ProgressView()
                }

                Spacer()

                if let onClear, result != nil || mode == .rawText {
                    Button("Clear", role: .destructive, action: onClear)
                        .buttonStyle(.borderless)
                }
            }

            Group {
                if mode == .rawText {
                    Text(rawText.isEmpty ? "No raw text available." : rawText)
                } else if let result {
                    Text(result)
                } else if !isLoading {
                    Text("Tap \"Summarize Now\" to generate a summary.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.body)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
