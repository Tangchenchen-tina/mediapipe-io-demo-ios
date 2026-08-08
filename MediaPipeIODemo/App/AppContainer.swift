import Foundation
import Observation
import SwiftData

/// Hand-rolled composition root — no DI framework, so "where does X come from" stays a one-hop
/// lookup for anyone reading this codebase for the first time. Mirrors the Android sibling app's
/// `IoDemoApplication`: every engine/repository is constructed once here and handed down through
/// the SwiftUI environment.
@Observable
@MainActor
final class AppContainer {
    let modelContainer: ModelContainer

    let summarizerEngine: TextSummarizerEngine
    let proofreaderEngine: TextProofreaderEngine
    let embedderEngine: TextEmbedderEngine

    let searchService: SemanticSearchService

    let chatRepository: ChatRepository
    let emailRepository: EmailRepository
    let archiveRepository: ArchiveRepository

    let demoDataSeeder: DemoDataSeeder

    init() {
        let schema = Schema([
            ChatThread.self, ChatMessage.self, EmailItem.self, ArchiveDocument.self, EmbeddingRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else {
            fatalError("Failed to create SwiftData ModelContainer")
        }
        modelContainer = container

        let mainContext = container.mainContext

        let summarizer = MediaPipeTextSummarizerEngine()
        let proofreader = MediaPipeTextProofreaderEngine()
        let embedder = MediaPipeTextEmbedderEngine()
        summarizerEngine = summarizer
        proofreaderEngine = proofreader
        embedderEngine = embedder

        let search = SemanticSearchService(container: container, embedderEngine: embedder)
        searchService = search

        chatRepository = ChatRepository(modelContext: mainContext, searchService: search, summarizerEngine: summarizer)
        emailRepository = EmailRepository(
            modelContext: mainContext, searchService: search, summarizerEngine: summarizer, proofreaderEngine: proofreader
        )
        archiveRepository = ArchiveRepository(modelContext: mainContext, searchService: search, summarizerEngine: summarizer)

        demoDataSeeder = DemoDataSeeder(modelContext: mainContext, searchService: search)
    }
}
