import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class ArchiveListViewModel {
    private let repository: ArchiveRepository
    private let seeder: DemoDataSeeder

    var indexedDocumentIds: Set<String> = []
    var isSearching = false
    var searchResults: [SearchMatch]?
    var thumbnails: [String: UIImage] = [:]
    var importError: String?
    var reembedProgress: EmbeddingProgress?

    init(repository: ArchiveRepository, seeder: DemoDataSeeder) {
        self.repository = repository
        self.seeder = seeder
        Task {
            await seeder.seedIfNeeded()
            await refreshIndexedIds()
        }
    }

    func refreshIndexedIds() async {
        indexedDocumentIds = await repository.indexedDocumentIds()
    }

    func search(_ query: String) {
        Task {
            isSearching = true
            searchResults = await repository.searchGlobal(query)
            isSearching = false
        }
    }

    /// Lazily renders and caches each grid card's page-0 thumbnail, matching the Android sibling
    /// app's per-item `LaunchedEffect`-driven thumbnail loading.
    func loadThumbnailIfNeeded(for document: ArchiveDocument) {
        guard thumbnails[document.id] == nil else { return }
        Task {
            if let image = repository.renderPage(document, pageIndex: 0) {
                thumbnails[document.id] = image
            }
        }
    }

    /// Imports a PDF picked via `.fileImporter` — e.g. from the user's Mac Desktop through the
    /// Files app — and runs the same first-two-pages embedding scan bundled documents get.
    func importDocument(from url: URL) {
        Task {
            do {
                _ = try await repository.importDocument(from: url)
                await refreshIndexedIds()
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    func reembedAll() {
        guard reembedProgress == nil else { return }
        Task {
            let start = Date()
            reembedProgress = EmbeddingProgress(done: 0, total: 0, itemsPerSecond: 0)
            await repository.reembedAllDocuments { [weak self] done, total in
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
