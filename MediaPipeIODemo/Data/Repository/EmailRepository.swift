import Foundation
import SwiftData

@MainActor
final class EmailRepository {
    private let modelContext: ModelContext
    private let searchService: SemanticSearchService
    private let summarizerEngine: TextSummarizerEngine
    private let proofreaderEngine: TextProofreaderEngine

    init(
        modelContext: ModelContext,
        searchService: SemanticSearchService,
        summarizerEngine: TextSummarizerEngine,
        proofreaderEngine: TextProofreaderEngine
    ) {
        self.modelContext = modelContext
        self.searchService = searchService
        self.summarizerEngine = summarizerEngine
        self.proofreaderEngine = proofreaderEngine
    }

    func email(id: String) -> EmailItem? {
        var descriptor = FetchDescriptor<EmailItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func allEmails() -> [EmailItem] {
        (try? modelContext.fetch(FetchDescriptor<EmailItem>())) ?? []
    }

    /// Summarizes the email body; caches the result on the record.
    @discardableResult
    func summarize(id: String, mode: SummaryMode) async throws -> String {
        guard let email = email(id: id) else { throw RepositoryError.notFound }
        let summary = try await summarizerEngine.summarize(text: email.body, mode: mode)
        email.summary = summary
        try? modelContext.save()
        return summary
    }

    /// Streaming variant, backing the floating-button summary popup. Doesn't persist as chunks
    /// arrive — the caller accumulates the stream and calls `saveSummary` once it completes, so a
    /// cancelled or failed stream never leaves a half-written summary on the record.
    func summarizeStreaming(id: String, mode: SummaryMode) async -> AsyncThrowingStream<String, Error> {
        guard let email = email(id: id) else {
            return AsyncThrowingStream { $0.finish(throwing: RepositoryError.notFound) }
        }
        return await summarizerEngine.summarizeStreaming(text: email.body, mode: mode)
    }

    func saveSummary(id: String, text: String) {
        guard let email = email(id: id) else { return }
        email.summary = text
        try? modelContext.save()
    }

    /// Streaming variant, backing the floating proofread button. Only the middle paragraphs go to
    /// the model — the greeting ("Hi team,") and sign-off ("Thanks,\nAlex") are pleasantries, not
    /// content worth correcting, and leaving them out of the prompt guarantees they stay untouched
    /// rather than relying on the model to leave them alone on its own. Generation itself streams,
    /// but the caller (see `EmailDetailViewModel.proofread`) only calls `saveProofread` once the
    /// full correction has landed, so the diff appears all at once rather than flickering through
    /// partial corrections mid-stream.
    func proofreadStreaming(id: String) async -> AsyncThrowingStream<String, Error> {
        guard let email = email(id: id) else {
            return AsyncThrowingStream { $0.finish(throwing: RepositoryError.notFound) }
        }
        let parts = splitEmailBody(email.body)
        return await proofreaderEngine.proofreadStreaming(text: parts.middle)
    }

    /// `text` is the corrected middle passage only, matching what `proofreadStreaming` sent to the
    /// model — this stitches it back together with the original (untouched) greeting and closing
    /// before saving, so the diff naturally renders those as unchanged and only the middle shows
    /// real corrections.
    func saveProofread(id: String, text: String) {
        guard let email = email(id: id) else { return }
        let parts = splitEmailBody(email.body)
        email.proofreadBody = EmailBodyParts(greeting: parts.greeting, middle: text, closing: parts.closing).joined()
        try? modelContext.save()
    }

    /// Clears the persisted summary/correction for this email, so the next visitor to open it — at
    /// a demo booth, minutes or hours later — sees the plain original body again, ready to run
    /// either feature from scratch. `email.body` itself is never touched by any of this.
    func resetDemoState(id: String) {
        guard let email = email(id: id) else { return }
        email.proofreadBody = nil
        email.summary = nil
        try? modelContext.save()
    }

    /// Recovers from a summarizer failure — see `TextSummarizerEngine.reset`.
    func resetSummarizerEngine() async {
        await summarizerEngine.reset()
    }

    /// Recovers from a proofreader failure — see `TextProofreaderEngine.reset`.
    func resetProofreaderEngine() async {
        await proofreaderEngine.reset()
    }

    func searchGlobal(_ query: String) async -> [SearchMatch] {
        await searchService.search(query: query, scope: .email)
    }

    func indexedEmailIds() async -> Set<String> {
        await searchService.indexedIds(scope: .email)
    }

    /// Force-overwrites every email's cached embedding vector, same subject+body text each
    /// email's initial index used — what the "Re-embed all" action calls.
    @discardableResult
    func reembedAllEmails(onProgress: @escaping (Int, Int) -> Void) async -> Int {
        let emails = allEmails()
        let total = emails.count
        var done = 0
        var succeeded = 0
        for email in emails {
            let ok = await searchService.reindex(
                id: email.id, scope: .email, parentId: nil,
                title: email.subject,
                snippet: "From: \(email.from) — \(String(email.body.prefix(120)))",
                textToEmbed: "\(email.subject)\n\(email.body)"
            )
            if ok { succeeded += 1 }
            done += 1
            onProgress(done, total)
        }
        return succeeded
    }
}
