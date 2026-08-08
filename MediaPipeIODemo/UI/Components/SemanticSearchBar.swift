import SwiftUI

/// The search bar + suggestion chips + ranked-results panel pattern shared by all three sections
/// (Chats/Archive/Email). Callers own the actual search call (each section's semantics — global
/// vs local, which `EmbeddingScope` — differ), this just renders the shared shell around it.
struct SemanticSearchBar: View {
    let placeholder: String
    let suggestions: [String]
    let isSearching: Bool
    let results: [SearchMatch]?
    let onSearch: (String) -> Void
    let onResultClick: (SearchMatch) -> Void

    @State private var query: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $query)
                    .submitLabel(.search)
                    .onSubmit { runSearch() }
                Button("Search") { runSearch() }
                    .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                query = suggestion
                                runSearch()
                            } label: {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemBackground))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color(.separator), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if isSearching {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let results {
                SearchResultsPanel(results: results, onResultClick: onResultClick)
            }
        }
    }

    private func runSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onSearch(query)
    }
}

private struct SearchResultsPanel: View {
    let results: [SearchMatch]
    let onResultClick: (SearchMatch) -> Void

    // Shrinking hides the whole panel, not just its list — it only comes back for a *new*
    // search (a fresh `results` value resets this to false via the `.id` below), not by
    // re-expanding the old one.
    @State private var dismissed = false

    var body: some View {
        Group {
            if !dismissed {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Top Semantic Matches" + (results.isEmpty ? "" : " (\(results.count))"))
                            .font(.headline)
                        Spacer()
                        Button {
                            dismissed = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        // Without an explicit plain style, a Button nested inside a List row
                        // alongside sibling Buttons (the result cards below) can end up with
                        // broken/ambiguous hit-testing — a well-known SwiftUI List gotcha. This
                        // was the actual cause of "closing Top Semantic Matches does not work".
                        .buttonStyle(.plain)
                        .accessibilityLabel("Shrink results")
                    }

                    if results.isEmpty {
                        Text("No matches found.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(results.enumerated()), id: \.element.id) { index, match in
                        Button {
                            onResultClick(match)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("[Match #\(index + 1)] \(match.title) (similarity: \(String(format: "%.2f", match.similarity)))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(match.snippet)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        // A fresh set of results gets a fresh view identity, which resets `dismissed` back to
        // false — the same effect as the Android sibling app's `rememberSaveable(results)`.
        .id(results.map(\.id).joined(separator: ","))
    }
}
