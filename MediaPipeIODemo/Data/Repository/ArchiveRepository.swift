import Foundation
import PDFKit
import SwiftData
import UIKit

@MainActor
final class ArchiveRepository {
    private let modelContext: ModelContext
    private let searchService: SemanticSearchService
    private let summarizerEngine: TextSummarizerEngine
    private let textExtractor = PdfTextExtractor()
    private let pageRenderer = PdfPageRenderer()
    private let importer = DocumentImporter()

    init(modelContext: ModelContext, searchService: SemanticSearchService, summarizerEngine: TextSummarizerEngine) {
        self.modelContext = modelContext
        self.searchService = searchService
        self.summarizerEngine = summarizerEngine
    }

    func document(id: String) -> ArchiveDocument? {
        var descriptor = FetchDescriptor<ArchiveDocument>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func allDocuments() -> [ArchiveDocument] {
        (try? modelContext.fetch(FetchDescriptor<ArchiveDocument>())) ?? []
    }

    func renderPage(_ document: ArchiveDocument, pageIndex: Int) -> UIImage? {
        pageRenderer.renderPage(document, pageIndex: pageIndex)
    }

    func extractPageText(_ document: ArchiveDocument, pageIndex: Int) -> String {
        textExtractor.extractPage(document, pageIndex: pageIndex)
    }

    /// The real `PDFDocument` for the viewer — used directly by `PDFKitView` (a `PDFView` wrapper)
    /// for continuous vertical scrolling and native text selection, rather than the page-by-page
    /// rendered-image approach `renderPage`/`extractPageText` use for the Archive grid thumbnails.
    func loadPDFDocument(_ document: ArchiveDocument) -> PDFDocument? {
        guard let url = DocumentLocator.url(for: document) else { return nil }
        return PDFDocument(url: url)
    }

    /// Stateless passthrough to the summarizer engine — used for the "select a page, summarize
    /// it" viewer action, which doesn't persist its result (matches the Chat/Archive ephemeral
    /// summary panels; only Email's summary is cached).
    func summarize(text: String, mode: SummaryMode) async throws -> String {
        try await summarizerEngine.summarize(text: text, mode: mode)
    }

    /// Streaming variant — backs the Archive viewer's floating-button summary popup.
    func summarizeStreaming(text: String, mode: SummaryMode) async -> AsyncThrowingStream<String, Error> {
        await summarizerEngine.summarizeStreaming(text: text, mode: mode)
    }

    /// Recovers from a summarizer failure — see `TextSummarizerEngine.reset`.
    func resetSummarizerEngine() async {
        await summarizerEngine.reset()
    }

    func searchGlobal(_ query: String) async -> [SearchMatch] {
        await searchService.search(query: query, scope: .archiveDocument)
    }

    func indexedDocumentIds() async -> Set<String> {
        await searchService.indexedIds(scope: .archiveDocument)
    }

    /// Force-overwrites every document's cached embedding vector, same "first two pages" text
    /// each document's initial index used — what the "Re-embed all" action calls.
    @discardableResult
    func reembedAllDocuments(onProgress: @escaping (Int, Int) -> Void) async -> Int {
        let documents = allDocuments()
        let total = documents.count
        var done = 0
        var succeeded = 0
        for document in documents {
            let text = textExtractor.extractFirstPages(document)
            let ok = await searchService.reindex(
                id: document.id, scope: .archiveDocument, parentId: nil,
                title: document.title, snippet: String(text.prefix(160)), textToEmbed: text
            )
            if ok { succeeded += 1 }
            done += 1
            onProgress(done, total)
        }
        return succeeded
    }

    /// Imports a user-picked PDF — e.g. from their Mac's Desktop via the Files picker — copies it
    /// into the app's own storage, adds it to the Archive list, and runs the same "initialization
    /// stage" embedding scan (first two pages) that bundled sample documents get at first launch.
    @discardableResult
    func importDocument(from sourceURL: URL, title: String? = nil) async throws -> ArchiveDocument {
        let destination = try importer.importFile(from: sourceURL)
        let fileName = destination.lastPathComponent
        let document = ArchiveDocument(
            id: "imported_\(UUID().uuidString)",
            title: title ?? (fileName as NSString).deletingPathExtension,
            fileName: fileName,
            source: .imported,
            pageCount: 1,
            importedAtMillis: Int64(Date().timeIntervalSince1970 * 1000)
        )
        document.pageCount = textExtractor.pageCount(document)
        modelContext.insert(document)
        try? modelContext.save()

        let text = textExtractor.extractFirstPages(document)
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await searchService.indexIfNeeded(
                id: document.id,
                scope: .archiveDocument,
                parentId: nil,
                title: document.title,
                snippet: String(text.prefix(160)),
                textToEmbed: text
            )
        }
        return document
    }

    func deleteImportedDocument(_ document: ArchiveDocument) {
        guard document.source == .imported else { return }
        if let url = DocumentLocator.url(for: document) {
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(document)
        try? modelContext.save()
    }
}
