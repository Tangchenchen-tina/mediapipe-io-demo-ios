import Foundation
import Observation

@Observable
@MainActor
final class EmailListViewModel {
    private let repository: EmailRepository

    var indexedEmailIds: Set<String> = []
    var isSearching = false
    var searchResults: [SearchMatch]?
    var reembedProgress: EmbeddingProgress?

    init(repository: EmailRepository) {
        self.repository = repository
        Task { await refreshIndexedIds() }
    }

    func refreshIndexedIds() async {
        indexedEmailIds = await repository.indexedEmailIds()
    }

    func search(_ query: String) {
        Task {
            isSearching = true
            searchResults = await repository.searchGlobal(query)
            isSearching = false
        }
    }

    func reembedAll() {
        guard reembedProgress == nil else { return }
        Task {
            let start = Date()
            reembedProgress = EmbeddingProgress(done: 0, total: 0, itemsPerSecond: 0)
            await repository.reembedAllEmails { [weak self] done, total in
                guard let self else { return }
                let elapsed = Date().timeIntervalSince(start)
                let rate = elapsed > 0 ? Double(done) / elapsed : 0
                self.reembedProgress = EmbeddingProgress(done: done, total: total, itemsPerSecond: rate)
            }
            reembedProgress = nil
            await refreshIndexedIds()
        }
    }
}
