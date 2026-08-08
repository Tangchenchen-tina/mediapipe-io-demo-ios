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
    var summaryError: String?
    var highlightedMessageId: String?
    private var summaryTask: Task<Void, Never>?
    private var highlightTask: Task<Void, Never>?

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
        summaryTask?.cancel()
        summaryLoading = true
        summaryResult = ""
        summaryError = nil
        summaryTask = Task {
            let stream = await repository.summarizeThreadStreaming(threadId: threadId, mode: mode)
            do {
                for try await chunk in stream {
                    if Task.isCancelled { return }
                    summaryResult = (summaryResult ?? "") + chunk
                }
            } catch {
                summaryError = error.localizedDescription
                // See ArchiveDocumentViewModel's identical reset — a failed generation can leave
                // the engine unusable for every call after it, so recover immediately.
                await repository.resetSummarizerEngine()
            }
            summaryLoading = false
        }
    }

    func clearSummary() {
        summaryTask?.cancel()
        summaryResult = nil
        summaryError = nil
        summaryLoading = false
    }

    /// Manual escape hatch next to the TL;DR/Keypoints buttons — lets you recreate the engine on
    /// demand rather than waiting for the next error to trigger the automatic reset.
    func resetEngine() {
        summaryTask?.cancel()
        summaryLoading = false
        summaryError = nil
        summaryResult = nil
        Task {
            await repository.resetSummarizerEngine()
        }
    }

    /// Briefly rings the matched message bubble so tapping a search result doesn't just scroll
    /// to it silently — you can actually tell which one matched.
    func flashHighlight(_ messageId: String) {
        highlightTask?.cancel()
        highlightedMessageId = messageId
        highlightTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled {
                highlightedMessageId = nil
            }
        }
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
