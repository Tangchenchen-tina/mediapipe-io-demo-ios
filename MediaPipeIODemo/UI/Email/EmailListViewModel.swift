import Foundation
import Observation

@Observable
@MainActor
final class EmailListViewModel {
    private let repository: EmailRepository

    var indexedEmailIds: Set<String> = []
    var isSearching = false
    var searchResults: [SearchMatch]?

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
}
