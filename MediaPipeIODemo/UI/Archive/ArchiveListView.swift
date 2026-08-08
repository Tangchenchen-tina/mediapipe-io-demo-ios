import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private let archiveSuggestions = ["Applications of sequence learning in pointer networks"]
private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

struct ArchiveListView: View {
    @State private var viewModel: ArchiveListViewModel
    @Query private var documents: [ArchiveDocument]
    @State private var path = NavigationPath()
    @State private var isImporterPresented = false

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: ArchiveListViewModel(repository: container.archiveRepository, seeder: container.demoDataSeeder))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SemanticSearchBar(
                        placeholder: "Search academic archives…",
                        suggestions: archiveSuggestions,
                        isSearching: viewModel.isSearching,
                        results: viewModel.searchResults,
                        onSearch: { viewModel.search($0) },
                        onResultClick: { path.append($0.id) }
                    )

                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(documents) { document in
                            Button {
                                path.append(document.id)
                            } label: {
                                DocumentCard(
                                    document: document,
                                    thumbnail: viewModel.thumbnails[document.id],
                                    isIndexed: viewModel.indexedDocumentIds.contains(document.id)
                                )
                                .onAppear { viewModel.loadThumbnailIfNeeded(for: document) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Archive")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .navigationDestination(for: String.self) { documentId in
                ArchiveDocumentView(documentId: documentId, container: container)
            }
            .task { await viewModel.refreshIndexedIds() }
            .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.pdf]) { result in
                switch result {
                case .success(let url):
                    viewModel.importDocument(from: url)
                case .failure(let error):
                    viewModel.importError = error.localizedDescription
                }
            }
            .alert("Import failed", isPresented: .constant(viewModel.importError != nil), presenting: viewModel.importError) { _ in
                Button("OK") { viewModel.importError = nil }
            } message: { message in
                Text(message)
            }
        }
    }
}

private struct DocumentCard: View {
    let document: ArchiveDocument
    let thumbnail: UIImage?
    let isIndexed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ProgressView()
                }
            }
            .aspectRatio(0.75, contentMode: .fit)

            HStack(alignment: .top) {
                Text(document.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer()
                EmbeddingStatusIcon(isIndexed: isIndexed)
            }

            HStack(spacing: 4) {
                Text("\(document.pageCount) page\(document.pageCount == 1 ? "" : "s")")
                if document.source == .imported {
                    Text("· Imported")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
