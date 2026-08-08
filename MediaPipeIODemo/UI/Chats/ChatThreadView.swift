import SwiftData
import SwiftUI

struct ChatThreadView: View {
    let threadId: String
    @State private var viewModel: ChatThreadViewModel
    @Query private var messages: [ChatMessage]
    @State private var thread: ChatThread?

    private let container: AppContainer
    // Tailored to this specific thread's actual seeded content, not a generic global list —
    // see `DemoDataSeeder.chatSearchSuggestions(forThreadId:)`.
    private let localSuggestions: [String]

    init(threadId: String, container: AppContainer) {
        self.threadId = threadId
        self.container = container
        self.localSuggestions = DemoDataSeeder.chatSearchSuggestions(forThreadId: threadId)
        _viewModel = State(initialValue: ChatThreadViewModel(threadId: threadId, repository: container.chatRepository))
        _messages = Query(filter: #Predicate<ChatMessage> { $0.threadId == threadId }, sort: \ChatMessage.timestampMillis)
    }

    var body: some View {
        // Wraps the search bar too (not just the List) so tapping a result can scroll straight to
        // the matching bubble — `proxy` needs to be in scope wherever `onResultClick` is wired up.
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // A genuinely separate, non-scrolling sibling above the List — not a List section
                // header. Section headers are measured for roughly-fixed height and don't reliably
                // resize when their content grows (e.g. the results panel appearing after a search),
                // which was clipping/hiding the bar once you tapped Search. This way it just isn't
                // part of the scrollable area at all, so it can grow and shrink freely.
                SemanticSearchBar(
                    placeholder: "Search conversation history…",
                    suggestions: localSuggestions,
                    isSearching: viewModel.isSearching,
                    results: viewModel.searchResults,
                    onSearch: { viewModel.search($0) },
                    onResultClick: { match in
                        withAnimation {
                            proxy.scrollTo(match.id, anchor: .center)
                        }
                        viewModel.flashHighlight(match.id)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .background(Color(.systemBackground))

                List {
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
                        MessageBubble(
                            message: message,
                            isIndexed: viewModel.indexedMessageIds.contains(message.id),
                            isHighlighted: viewModel.highlightedMessageId == message.id
                        )
                        .padding(.top, isFirstInGroup ? 10 : 2)
                        .listRowSeparator(.hidden)
                        .id(message.id)
                    }

                    SummarizerPanel(
                        title: "History Summarizer",
                        rawText: "",
                        includeRawTextMode: false,
                        isLoading: viewModel.summaryLoading,
                        result: viewModel.summaryResult,
                        error: viewModel.summaryError,
                        onGenerate: { viewModel.summarize(mode: $0) },
                        onClear: { viewModel.clearSummary() },
                        onResetEngine: { viewModel.resetEngine() }
                    )
                    .listRowSeparator(.hidden)
                    .padding(.top, 8)
                    .id("summaryPanel")
                }
                .listStyle(.plain)
                .task {
                    thread = container.chatRepository.thread(id: threadId)
                    // Scroll to the summarizer panel rather than the last message — its anchor sits
                    // past the newest message, so entering the chat surfaces both the latest message
                    // and the History Summarizer section in one motion, like a normal chat app that
                    // also happens to have a summary section pinned at the end.
                    proxy.scrollTo("summaryPanel", anchor: .bottom)
                }
            }
        }
        .navigationTitle(thread?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
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
    let isHighlighted: Bool

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
                    .overlay(
                        bubbleShape.stroke(Color.yellow, lineWidth: isHighlighted ? 3 : 0)
                    )
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
