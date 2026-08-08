import PDFKit
import SwiftUI

struct ArchiveDocumentView: View {
    let documentId: String
    @State private var viewModel: ArchiveDocumentViewModel

    init(documentId: String, container: AppContainer) {
        self.documentId = documentId
        _viewModel = State(initialValue: ArchiveDocumentViewModel(documentId: documentId, repository: container.archiveRepository))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let pdfDocument = viewModel.pdfDocument {
                // Real PDFKit PDFView — continuous vertical scrolling and native drag-to-select
                // text selection, not a custom page-by-page renderer.
                PDFKitView(document: pdfDocument, mode: viewModel.mode) { text in
                    viewModel.selectedText = text
                }
                .ignoresSafeArea(edges: .bottom)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if viewModel.canSummarize {
                Button {
                    viewModel.summarizeSelection()
                } label: {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(radius: 6, y: 2)
                }
                .padding(20)
                .transition(.scale.combined(with: .opacity))
            }

            if viewModel.isSummaryBubbleVisible {
                SummaryBubble(
                    text: viewModel.streamingSummary,
                    isStreaming: viewModel.isStreaming,
                    error: viewModel.streamError,
                    onClose: { viewModel.dismissSummaryBubble() }
                )
                .padding(.trailing, 20)
                .padding(.bottom, viewModel.canSummarize ? 88 : 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: viewModel.canSummarize)
        .animation(.spring(duration: 0.25), value: viewModel.isSummaryBubbleVisible)
        .navigationTitle(viewModel.document?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $viewModel.mode) {
                    ForEach(ArchiveViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
        }
    }
}

/// The "message bubble like pop out box" — a floating card near the summarize button that fills
/// in as MediaPipe streams the summary, rather than appearing all at once.
private struct SummaryBubble: View {
    let text: String
    let isStreaming: Bool
    let error: String?
    let onClose: () -> Void

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

            if let error {
                Text("Couldn't summarize: \(error)")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else {
                Text(text.isEmpty ? " " : text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

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
}
