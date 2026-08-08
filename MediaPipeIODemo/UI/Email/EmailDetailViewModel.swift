import Foundation
import Observation

@Observable
@MainActor
final class EmailDetailViewModel {
    let emailId: String
    private let repository: EmailRepository
    private var summaryTask: Task<Void, Never>?
    private var proofreadTask: Task<Void, Never>?

    // Same pattern as the Archive viewer's bubble: the popup's own transient state, independent
    // of the persisted `email.summary` it eventually writes to.
    var isSummaryBubbleVisible = false
    var summaryMode: SummaryMode = .tldr
    var streamingSummary = ""
    var isStreaming = false
    var streamError: String?

    var proofreadLoading = false
    var streamingCorrectedText = ""
    var errorMessage: String?

    init(emailId: String, repository: EmailRepository) {
        self.emailId = emailId
        self.repository = repository
    }

    func summarize() {
        summaryMode = .tldr
        runSummarization()
    }

    /// What the bubble's own TL;DR/Keypoints toggle calls to re-stream without closing.
    func regenerateSummary(mode: SummaryMode) {
        summaryMode = mode
        runSummarization()
    }

    private func runSummarization() {
        summaryTask?.cancel()
        isSummaryBubbleVisible = true
        streamingSummary = ""
        streamError = nil
        isStreaming = true

        let mode = summaryMode
        let id = emailId
        summaryTask = Task {
            let stream = await repository.summarizeStreaming(id: id, mode: mode)
            do {
                for try await chunk in stream {
                    if Task.isCancelled { return }
                    streamingSummary += chunk
                }
                // Only persisted once the full stream lands — a cancelled or failed run never
                // leaves a half-written summary on the record.
                repository.saveSummary(id: id, text: streamingSummary)
            } catch {
                streamError = error.localizedDescription
                // See ArchiveDocumentViewModel's identical reset — a failed generation can leave
                // the engine unusable for every call after it, so recover immediately.
                await repository.resetSummarizerEngine()
            }
            isStreaming = false
        }
    }

    func dismissSummaryBubble() {
        summaryTask?.cancel()
        isSummaryBubbleVisible = false
        isStreaming = false
    }

    /// Manual escape hatch next to the TL;DR/Keypoints buttons — lets you recreate the engine on
    /// demand rather than waiting for the next error to trigger the automatic reset.
    func resetEngine() {
        summaryTask?.cancel()
        isStreaming = false
        streamError = nil
        streamingSummary = ""
        Task {
            await repository.resetSummarizerEngine()
        }
    }

    /// Always proofreads the original `email.body` — never the previous correction — so trying
    /// again after editing your mental model of the email re-runs against the real source text.
    /// While streaming, `streamingCorrectedText` grows from empty to the full corrected text so
    /// the generation is visibly live; the word-diff only replaces it once the stream completes
    /// (via `email.proofreadBody`), so the diff itself never flickers through partial/incorrect
    /// states mid-sentence. `email.body` itself is never touched.
    func proofread() {
        proofreadTask?.cancel()
        proofreadLoading = true
        streamingCorrectedText = ""
        errorMessage = nil

        let id = emailId
        proofreadTask = Task {
            let stream = await repository.proofreadStreaming(id: id)
            do {
                for try await chunk in stream {
                    if Task.isCancelled { return }
                    streamingCorrectedText += chunk
                }
                if !Task.isCancelled {
                    repository.saveProofread(id: id, text: streamingCorrectedText)
                }
            } catch {
                errorMessage = error.localizedDescription
                await repository.resetProofreaderEngine()
            }
            proofreadLoading = false
        }
    }

    /// Called when the detail screen disappears (back navigation). This is a demo-booth app —
    /// every visitor should find every email in its plain, unproofread state, ready to run the
    /// features themselves rather than inheriting the last person's result.
    func resetOnQuit() {
        summaryTask?.cancel()
        proofreadTask?.cancel()
        repository.resetDemoState(id: emailId)
    }
}
