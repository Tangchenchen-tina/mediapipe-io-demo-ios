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

    // Once the bubble opens, everything about it — text, mode, streamed output — lives here,
    // completely independent of `selectedText`/`mode` above. Earlier this read `selectedText`
    // live, so switching Preview/Select/Select Page while the bubble was open (which changes or
    // clears `selectedText`) made the bubble's content vanish out from under it. Freezing the
    // target text at the moment the bubble opens fixes that and is also just better UX — the
    // thing you're reading a summary of shouldn't silently change while you're reading it.
    var isSummaryBubbleVisible = false
    var summarizingText: String?
    var summaryMode: SummaryMode = .tldr
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

    /// Opens the bubble for the current selection, starting from TL;DR.
    func summarizeSelection() {
        guard let text = selectedText, !text.isEmpty else { return }
        summarizingText = text
        summaryMode = .tldr
        runSummarization()
    }

    /// Re-runs streaming summarization on the same frozen text — what the bubble's own TL;DR /
    /// Keypoints toggle calls, so switching mode after the bubble is already open works.
    func regenerateSummary(mode: SummaryMode) {
        summaryMode = mode
        runSummarization()
    }

    private func runSummarization() {
        guard let text = summarizingText else { return }
        streamingTask?.cancel()
        isSummaryBubbleVisible = true
        streamingSummary = ""
        streamError = nil
        isStreaming = true

        let mode = summaryMode
        streamingTask = Task {
            let stream = await repository.summarizeStreaming(text: text, mode: mode)
            do {
                for try await chunk in stream {
                    if Task.isCancelled { return }
                    streamingSummary += chunk
                }
            } catch {
                streamError = error.localizedDescription
                // Some inputs (a large/malformed PDF page in particular) have been observed to
                // leave the engine unusable for every call after the one that failed, not just
                // that one — reset immediately so the very next attempt gets a fresh instance
                // instead of failing again for a reason that has nothing to do with its own input.
                await repository.resetSummarizerEngine()
            }
            isStreaming = false
        }
    }

    func dismissSummaryBubble() {
        streamingTask?.cancel()
        isSummaryBubbleVisible = false
        isStreaming = false
        summarizingText = nil
    }

    /// Manual escape hatch next to the TL;DR/Keypoints buttons — lets you recreate the engine on
    /// demand rather than waiting for the next error to trigger the automatic reset.
    func resetEngine() {
        streamingTask?.cancel()
        isStreaming = false
        streamError = nil
        streamingSummary = ""
        Task {
            await repository.resetSummarizerEngine()
        }
    }
}
