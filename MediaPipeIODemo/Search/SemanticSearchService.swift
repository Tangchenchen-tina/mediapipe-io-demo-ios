import Foundation
import SwiftData

/// The one place anything in this app asks "what's semantically similar to X" — used for global
/// search in all three sections and local, in-thread chat search. Mirrors the Android sibling
/// app's `SemanticSearchService` exactly, including the idempotent-indexing and force-reindex
/// split that the "Re-embed" UI actions rely on.
///
/// Runs as an `actor` around its own background `ModelContext` (SwiftData contexts aren't safe to
/// share across threads) — separate from the `ModelContext` SwiftUI's `@Query` uses on the main
/// actor, but both read/write the same underlying store via the shared `ModelContainer`, so
/// changes made here still show up in `@Query`-driven views.
actor SemanticSearchService {
    private let container: ModelContainer
    // Created lazily, on first real access from within this actor's own isolated methods —
    // NOT eagerly in `init`, since `init` runs on whatever actor constructs this service
    // (the main actor, via `AppContainer`). A `ModelContext` is bound to the queue it's created
    // on, so building it eagerly in `init` would bind it to the main queue and then get used off
    // that queue here, which SwiftData warns about at runtime ("Unbinding from the main queue").
    private lazy var context: ModelContext = ModelContext(container)
    private let embedderEngine: TextEmbedderEngine

    init(container: ModelContainer, embedderEngine: TextEmbedderEngine) {
        self.container = container
        self.embedderEngine = embedderEngine
    }

    /// Embeds and stores [textToEmbed] under [id], unless already indexed — the "initialization
    /// stage" scan calls this once per chat/message/email/document at startup and is a no-op on
    /// every later launch.
    func indexIfNeeded(id: String, scope: EmbeddingScope, parentId: String?, title: String, snippet: String, textToEmbed: String) async {
        guard !exists(id: id) else { return }
        _ = await reindex(id: id, scope: scope, parentId: parentId, title: title, snippet: snippet, textToEmbed: textToEmbed)
    }

    /// Embeds and stores unconditionally, overwriting any existing vector — what the "Re-embed"
    /// actions use to pick up content that's changed since the last scan. Returns success.
    @discardableResult
    func reindex(id: String, scope: EmbeddingScope, parentId: String?, title: String, snippet: String, textToEmbed: String) async -> Bool {
        do {
            let vector = try await embedderEngine.embed(text: textToEmbed)
            upsert(EmbeddingRecord(id: id, scope: scope, parentId: parentId, title: title, snippet: snippet, vector: vector))
            return true
        } catch {
            return false
        }
    }

    /// Ranks everything indexed under [scope] (optionally restricted to one [parentId]) against
    /// [query], most similar first.
    func search(query: String, scope: EmbeddingScope, parentId: String? = nil, topK: Int = 3) async -> [SearchMatch] {
        do {
            let queryVector = try await embedderEngine.embed(text: query)
            return fetchCandidates(scope: scope, parentId: parentId)
                .map { SearchMatch(id: $0.id, title: $0.title, snippet: $0.snippet, similarity: cosineSimilarity(queryVector, $0.floatValues)) }
                .sorted { $0.similarity > $1.similarity }
                .prefix(topK)
                .map { $0 }
        } catch {
            return []
        }
    }

    /// Every id within [scope] (optionally narrowed to one [parentId]) that's indexed right now —
    /// powers the embedded/not-embedded status badges.
    func indexedIds(scope: EmbeddingScope, parentId: String? = nil) -> Set<String> {
        Set(fetchCandidates(scope: scope, parentId: parentId).map(\.id))
    }

    func isIndexed(id: String) -> Bool {
        exists(id: id)
    }

    // MARK: - SwiftData plumbing

    private func exists(id: String) -> Bool {
        let descriptor = FetchDescriptor<EmbeddingRecord>(predicate: #Predicate { $0.id == id })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private func upsert(_ record: EmbeddingRecord) {
        let recordId = record.id
        if let existing = try? context.fetch(FetchDescriptor<EmbeddingRecord>(predicate: #Predicate<EmbeddingRecord> { $0.id == recordId })).first {
            context.delete(existing)
        }
        context.insert(record)
        try? context.save()
    }

    private func fetchCandidates(scope: EmbeddingScope, parentId: String?) -> [EmbeddingRecord] {
        let scopeRaw = scope.rawValue
        let descriptor: FetchDescriptor<EmbeddingRecord>
        if let parentId {
            descriptor = FetchDescriptor<EmbeddingRecord>(
                predicate: #Predicate { $0.scopeRaw == scopeRaw && $0.parentId == parentId }
            )
        } else {
            descriptor = FetchDescriptor<EmbeddingRecord>(predicate: #Predicate { $0.scopeRaw == scopeRaw })
        }
        return (try? context.fetch(descriptor)) ?? []
    }
}
