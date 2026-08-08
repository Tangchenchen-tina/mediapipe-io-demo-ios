import Foundation
import SwiftData

/// Operates on the app's main `ModelContext` — the same one SwiftUI's `@Query` uses for reactive
/// list rendering — so it must stay on the main actor. Search/embedding work is delegated to the
/// `SemanticSearchService` actor, which runs on its own background context.
@MainActor
final class ChatRepository {
    private let modelContext: ModelContext
    private let searchService: SemanticSearchService
    private let summarizerEngine: TextSummarizerEngine

    init(modelContext: ModelContext, searchService: SemanticSearchService, summarizerEngine: TextSummarizerEngine) {
        self.modelContext = modelContext
        self.searchService = searchService
        self.summarizerEngine = summarizerEngine
    }

    func thread(id: String) -> ChatThread? {
        var descriptor = FetchDescriptor<ChatThread>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func messages(threadId: String) -> [ChatMessage] {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.threadId == threadId },
            sortBy: [SortDescriptor(\.timestampMillis, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func allThreads() -> [ChatThread] {
        (try? modelContext.fetch(FetchDescriptor<ChatThread>())) ?? []
    }

    /// Summarizes the whole thread's transcript. Not persisted — matches the reference app's
    /// ephemeral, "Clear"-able summary panel.
    func summarizeThread(threadId: String, mode: SummaryMode) async throws -> String {
        let transcript = buildTranscript(messages(threadId: threadId))
        return try await summarizerEngine.summarize(text: transcript, mode: mode)
    }

    func searchGlobal(_ query: String) async -> [SearchMatch] {
        await searchService.search(query: query, scope: .chatThread)
    }

    func searchWithinThread(_ threadId: String, query: String) async -> [SearchMatch] {
        await searchService.search(query: query, scope: .chatMessage, parentId: threadId)
    }

    func indexedThreadIds() async -> Set<String> {
        await searchService.indexedIds(scope: .chatThread)
    }

    func isThreadIndexed(_ threadId: String) async -> Bool {
        await searchService.isIndexed(id: threadId)
    }

    func indexedMessageIds(threadId: String) async -> Set<String> {
        await searchService.indexedIds(scope: .chatMessage, parentId: threadId)
    }

    @discardableResult
    func reembedThread(_ threadId: String, onProgress: @escaping (Int, Int) -> Void) async -> Int {
        guard let thread = thread(id: threadId) else { return 0 }
        return await reembed([(thread, messages(threadId: threadId))], onProgress: onProgress)
    }

    @discardableResult
    func reembedAllThreads(onProgress: @escaping (Int, Int) -> Void) async -> Int {
        let threads = allThreads()
        let pairs = threads.map { ($0, messages(threadId: $0.id)) }
        return await reembed(pairs, onProgress: onProgress)
    }

    private func reembed(_ pairs: [(ChatThread, [ChatMessage])], onProgress: @escaping (Int, Int) -> Void) async -> Int {
        let total = pairs.reduce(0) { $0 + 1 + $1.1.count }
        var done = 0
        var succeeded = 0
        for (thread, messages) in pairs {
            let transcript = buildTranscript(messages)
            let snippet = messages.last?.text ?? ""
            let threadOk = await searchService.reindex(
                id: thread.id, scope: .chatThread, parentId: nil, title: thread.title, snippet: snippet, textToEmbed: transcript
            )
            if threadOk { succeeded += 1 }
            done += 1
            onProgress(done, total)

            for message in messages {
                let messageOk = await searchService.reindex(
                    id: message.id, scope: .chatMessage, parentId: thread.id, title: thread.title,
                    snippet: message.text, textToEmbed: message.text
                )
                if messageOk { succeeded += 1 }
                done += 1
                onProgress(done, total)
            }
        }
        return succeeded
    }

    private func buildTranscript(_ messages: [ChatMessage]) -> String {
        messages
            .map { message in "\(message.sender == .me ? "Me" : "Them"): \(message.text)" }
            .joined(separator: "\n")
    }
}
