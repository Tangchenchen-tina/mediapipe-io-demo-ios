import SwiftData
import SwiftUI

struct EmailDetailView: View {
    let emailId: String
    @Query private var emails: [EmailItem]
    @State private var viewModel: EmailDetailViewModel

    private var email: EmailItem? { emails.first }

    init(emailId: String, container: AppContainer) {
        self.emailId = emailId
        _emails = Query(filter: #Predicate<EmailItem> { $0.id == emailId })
        _viewModel = State(initialValue: EmailDetailViewModel(emailId: emailId, repository: container.emailRepository))
    }

    var body: some View {
        List {
            if let email {
                VStack(alignment: .leading, spacing: 6) {
                    Text(email.subject)
                        .font(.title3.bold())
                    Text("\(email.from) → \(email.to)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatRelativeTime(email.timestampMillis))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(email.body)
                        .font(.body)
                        .padding(.top, 6)
                }
                .listRowSeparator(.hidden)

                SummarizerPanel(
                    title: "Document Summarizer",
                    rawText: email.body,
                    includeRawTextMode: true,
                    isLoading: viewModel.summaryLoading,
                    result: email.summary,
                    onGenerate: { viewModel.summarize(mode: $0) },
                    // Summary is persisted on the record, not ephemeral view state — no Clear
                    // affordance, matching the Android sibling app's `onClear = null` for Email.
                    onClear: nil
                )
                .listRowSeparator(.hidden)

                ProofreaderPanel(
                    originalText: email.body,
                    correctedText: email.proofreadBody,
                    isLoading: viewModel.proofreadLoading,
                    onProofread: { viewModel.proofread() }
                )
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle(email?.subject ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}
