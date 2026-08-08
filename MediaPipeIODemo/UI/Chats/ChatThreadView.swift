import SwiftData
import SwiftUI

private let localChatSuggestions = ["Flight departure time?", "JR train pass?"]

struct ChatThreadView: View {
    let threadId: String
    @State private var viewModel: ChatThreadViewModel
    @Query private var messages: [ChatMessage]
    @State private var thread: ChatThread?

    private let container: AppContainer

    init(threadId: String, container: AppContainer) {
        self.threadId = threadId
        self.container = container
        _viewModel = State(initialValue: ChatThreadViewModel(threadId: threadId, repository: container.chatRepository))
        _messages = Query(filter: #Predicate<ChatMessage> { $0.threadId == threadId }, sort: \ChatMessage.timestampMillis)
    }

    var body: some View {
        List {
            SemanticSearchBar(
                placeholder: "Search conversation history…",
                suggestions: localChatSuggestions,
                isSearching: viewModel.isSearching,
                results: viewModel.searchResults,
                onSearch: { viewModel.search($0) },
                onResultClick: { _ in }
            )
            .listRowSeparator(.hidden)

            ThreadEmbeddingStatusBar(
                isThreadIndexed: viewModel.isThreadIndexed,
                embeddedMessageCount: viewModel.indexedMessageIds.count,
                totalMessageCount: messages.count,
                progress: viewModel.reembedProgress,
                onReembed: { viewModel.reembedThisChat() }
            )
            .listRowSeparator(.hidden)

            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                let isFirstInGroup = index == 0 || messages[index - 1].sender != message.sender
                MessageBubble(message: message, isIndexed: viewModel.indexedMessageIds.contains(message.id))
                    .padding(.top, isFirstInGroup ? 10 : 2)
                    .listRowSeparator(.hidden)
            }

            SummarizerPanel(
                title: "History Summarizer",
                rawText: "",
                includeRawTextMode: false,
                isLoading: viewModel.summaryLoading,
                result: viewModel.summaryResult,
                onGenerate: { viewModel.summarize(mode: $0) },
                onClear: { viewModel.clearSummary() }
            )
            .listRowSeparator(.hidden)
            .padding(.top, 8)
        }
        .listStyle(.plain)
        .navigationTitle(thread?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            thread = container.chatRepository.thread(id: threadId)
        }
    }
}

private struct ThreadEmbeddingStatusBar: View {
    let isThreadIndexed: Bool
    let embeddedMessageCount: Int
    let totalMessageCount: Int
    let progress: EmbeddingProgress?
    let onReembed: () -> Void

    var body: some View {
        Group {
            if let progress {
                EmbeddingProgressView(progress: progress)
            } else {
                HStack {
                    HStack(spacing: 6) {
                        EmbeddingStatusIcon(isIndexed: isThreadIndexed)
                        Text("\(embeddedMessageCount)/\(totalMessageCount) messages embedded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Re-embed", action: onReembed)
                        .font(.caption)
                        .disabled(totalMessageCount == 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Tail-shaped bubble (rounded on three corners, pulled tight on the fourth) with a solid,
/// contrasting fill — a real chat-bubble look, not just a tinted text box.
private struct MessageBubble: View {
    let message: ChatMessage
    let isIndexed: Bool

    private var isMe: Bool { message.sender == .me }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if isMe { Spacer(minLength: 40) }
            if !isMe { EmbeddingStatusIcon(isIndexed: isIndexed) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isMe ? Color.white : Color.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMe ? Color.accentColor : Color(.secondarySystemBackground))
                    .clipShape(bubbleShape)
                    .frame(maxWidth: 280, alignment: isMe ? .trailing : .leading)
                Text(formatTime(message.timestampMillis))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }

            if isMe { EmbeddingStatusIcon(isIndexed: isIndexed) }
            if !isMe { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isMe ? .trailing : .leading)
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: isMe ? 18 : 4,
            bottomTrailingRadius: isMe ? 4 : 18,
            topTrailingRadius: 18
        )
    }
}
