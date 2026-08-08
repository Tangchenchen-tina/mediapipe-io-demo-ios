import Foundation
import Observation
import PDFKit

@Observable
@MainActor
final class ArchiveDocumentViewModel {
    let documentId: String
    private let repository: ArchiveRepository
    private var streamingTask: Task<Void, Never>?

    var document: ArchiveDocument?
    var pdfDocument: PDFDocument?

    var mode: ArchiveViewMode = .preview {
        didSet {
            if mode == .preview {
                selectedText = nil
            }
        }
    }
    var selectedText: String?

    var isSummaryBubbleVisible = false
    var streamingSummary = ""
    var isStreaming = false
    var streamError: String?

    init(documentId: String, repository: ArchiveRepository) {
        self.documentId = documentId
        self.repository = repository
        document = repository.document(id: documentId)
        if let document {
            pdfDocument = repository.loadPDFDocument(document)
        }
    }

    var canSummarize: Bool {
        mode != .preview && !(selectedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func summarizeSelection(mode summaryMode: SummaryMode = .tldr) {
        guard let text = selectedText, !text.isEmpty else { return }
        streamingTask?.cancel()
        isSummaryBubbleVisible = true
        streamingSummary = ""
        streamError = nil
        isStreaming = true

        streamingTask = Task {
            let stream = await repository.summarizeStreaming(text: text, mode: summaryMode)
            do {
                for try await chunk in stream {
                    if Task.isCancelled { return }
                    streamingSummary += chunk
                }
            } catch {
                streamError = error.localizedDescription
            }
            isStreaming = false
        }
    }

    func dismissSummaryBubble() {
        streamingTask?.cancel()
        isSummaryBubbleVisible = false
        isStreaming = false
    }
}
