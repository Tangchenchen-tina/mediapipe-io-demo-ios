import SwiftData
import SwiftUI

// Grounded in what's actually in the 5 seeded emails, not a generic/mismatched placeholder.
private let emailSuggestions = [
    "architecture review schedule",
    "compliance training deadline",
    "marketing campaign launch date",
]

struct EmailListView: View {
    @State private var viewModel: EmailListViewModel
    @Query(sort: \EmailItem.timestampMillis, order: .reverse) private var emails: [EmailItem]
    @State private var path = NavigationPath()

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: EmailListViewModel(repository: container.emailRepository))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                SemanticSearchBar(
                    placeholder: "Search standard emails…",
                    suggestions: emailSuggestions,
                    isSearching: viewModel.isSearching,
                    results: viewModel.searchResults,
                    onSearch: { viewModel.search($0) },
                    onResultClick: { path.append($0.id) }
                )
                .listRowSeparator(.hidden)

                EmbeddingStatusBar(
                    itemLabel: "emails",
                    embeddedCount: viewModel.indexedEmailIds.count,
                    totalCount: emails.count,
                    progress: viewModel.reembedProgress,
                    onReembedAll: { viewModel.reembedAll() }
                )
                .listRowSeparator(.hidden)

                ForEach(emails) { email in
                    Button {
                        path.append(email.id)
                    } label: {
                        EmailRow(email: email, isIndexed: viewModel.indexedEmailIds.contains(email.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Email")
            .navigationDestination(for: String.self) { emailId in
                EmailDetailView(emailId: emailId, container: container)
            }
            .task { await viewModel.refreshIndexedIds() }
        }
    }
}

private struct EmailRow: View {
    let email: EmailItem
    let isIndexed: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(String(email.from.prefix(1)).uppercased())
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(email.subject)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("From: \(email.from)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(formatRelativeTime(email.timestampMillis))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            EmbeddingStatusIcon(isIndexed: isIndexed)
        }
        .padding(.vertical, 6)
    }
}
