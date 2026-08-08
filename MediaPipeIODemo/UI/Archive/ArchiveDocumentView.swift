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
                .accessibilityIdentifier("archivePDFView")
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
                .accessibilityIdentifier("archiveSummarizeButton")
                .padding(20)
            }

            if viewModel.isSummaryBubbleVisible {
                SummaryBubble(
                    text: viewModel.streamingSummary,
                    isStreaming: viewModel.isStreaming,
                    error: viewModel.streamError,
                    mode: viewModel.summaryMode,
                    onSelectMode: { viewModel.regenerateSummary(mode: $0) },
                    onClose: { viewModel.dismissSummaryBubble() },
                    onResetEngine: { viewModel.resetEngine() }
                )
                .padding(.trailing, 20)
                .padding(.bottom, viewModel.canSummarize ? 88 : 20)
            }
        }
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
