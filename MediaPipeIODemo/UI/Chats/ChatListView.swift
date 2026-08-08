import SwiftData
import SwiftUI

private let globalChatSuggestions = ["PostgreSQL caching optimization", "Kyoto travel planner bullet train"]

struct ChatListView: View {
    @State private var viewModel: ChatListViewModel
    @Query(sort: \ChatThread.lastUpdatedMillis, order: .reverse) private var threads: [ChatThread]
    @State private var path = NavigationPath()

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: ChatListViewModel(repository: container.chatRepository, seeder: container.demoDataSeeder))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                SemanticSearchBar(
                    placeholder: "Search direct messages",
                    suggestions: globalChatSuggestions,
                    isSearching: viewModel.isSearching,
                    results: viewModel.searchResults,
                    onSearch: { viewModel.search($0) },
                    onResultClick: { path.append($0.id) }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                EmbeddingStatusBar(
                    embeddedCount: viewModel.indexedThreadIds.count,
                    totalCount: threads.count,
                    progress: viewModel.reembedProgress,
                    onReembedAll: { viewModel.reembedAll() }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))

                ForEach(threads) { thread in
                    Button {
                        path.append(thread.id)
                    } label: {
                        ChatThreadRow(thread: thread, isIndexed: viewModel.indexedThreadIds.contains(thread.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chats")
            .navigationDestination(for: String.self) { threadId in
                ChatThreadView(threadId: threadId, container: container)
            }
            .task { await viewModel.refreshIndexedIds() }
        }
    }
}

private struct EmbeddingStatusBar: View {
    let embeddedCount: Int
    let totalCount: Int
    let progress: EmbeddingProgress?
    let onReembedAll: () -> Void

    var body: some View {
        Group {
            if let progress {
                EmbeddingProgressView(progress: progress)
            } else {
                HStack {
                    Text("\(embeddedCount)/\(totalCount) chats embedded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Re-embed all", action: onReembedAll)
                        .font(.caption)
                        .disabled(totalCount == 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ChatThreadRow: View {
    let thread: ChatThread
    let isIndexed: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(thread.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(thread.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(thread.lastMessagePreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(formatRelativeTime(thread.lastUpdatedMillis))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            EmbeddingStatusIcon(isIndexed: isIndexed)
        }
        .padding(.vertical, 6)
    }
}
