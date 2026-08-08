import Foundation
import Observation

@Observable
@MainActor
final class ChatThreadViewModel {
    let threadId: String
    private let repository: ChatRepository

    var isThreadIndexed = false
    var indexedMessageIds: Set<String> = []
    var reembedProgress: EmbeddingProgress?
    var isSearching = false
    var searchResults: [SearchMatch]?
    var summaryLoading = false
    var summaryResult: String?

    init(threadId: String, repository: ChatRepository) {
        self.threadId = threadId
        self.repository = repository
        Task { await refreshIndexedState() }
    }

    func refreshIndexedState() async {
        isThreadIndexed = await repository.isThreadIndexed(threadId)
        indexedMessageIds = await repository.indexedMessageIds(threadId: threadId)
    }

    func search(_ query: String) {
        Task {
            isSearching = true
            searchResults = await repository.searchWithinThread(threadId, query: query)
            isSearching = false
        }
    }

    func summarize(mode: SummaryMode) {
        Task {
            summaryLoading = true
            do {
                summaryResult = try await repository.summarizeThread(threadId: threadId, mode: mode)
            } catch {
                summaryResult = "Couldn't summarize this thread: \(error.localizedDescription)"
            }
            summaryLoading = false
        }
    }

    func clearSummary() {
        summaryResult = nil
    }

    func reembedThisChat() {
        guard reembedProgress == nil else { return }
        Task {
            let start = Date()
            reembedProgress = EmbeddingProgress(done: 0, total: 0, itemsPerSecond: 0)
            await repository.reembedThread(threadId) { [weak self] done, total in
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(start)
                let rate = elapsed > 0 ? Double(done) / elapsed : 0
                self.reembedProgress = EmbeddingProgress(done: done, total: total, itemsPerSecond: rate)
            }
            reembedProgress = nil
            await refreshIndexedState()
        }
    }
}
