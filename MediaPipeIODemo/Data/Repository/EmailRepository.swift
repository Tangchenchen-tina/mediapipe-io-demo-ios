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

    /// Corrects the email body; caches the result on the record — this is what "view corrected
    /// version" reads.
    @discardableResult
    func proofread(id: String) async throws -> String {
        guard let email = email(id: id) else { throw RepositoryError.notFound }
        let corrected = try await proofreaderEngine.proofread(text: email.body)
        email.proofreadBody = corrected
        try? modelContext.save()
        return corrected
    }

    func searchGlobal(_ query: String) async -> [SearchMatch] {
        await searchService.search(query: query, scope: .email)
    }

    func indexedEmailIds() async -> Set<String> {
        await searchService.indexedIds(scope: .email)
    }
}
