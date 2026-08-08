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
        ZStack(alignment: .bottomTrailing) {
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

                        // Once proofread, the diff renders directly in place of the plain body —
                        // `email.body` itself is never overwritten, so this always reflects the
                        // real original text plus whatever the latest correction pass found. While
                        // a correction is streaming in, the growing plain text shows generation
                        // happening live, in natural reading order: the opening greeting is there
                        // from the start, and the closing sign-off only appends once the stream
                        // completes — like reading a letter, not like the sign-off floating below
                        // an unfinished paragraph the whole time.
                        Group {
                            if let corrected = email.proofreadBody {
                                diffText(original: email.body, corrected: corrected)
                            } else if viewModel.proofreadLoading {
                                let parts = splitEmailBody(email.body)
                                Text(EmailBodyParts(greeting: parts.greeting, middle: viewModel.streamingCorrectedText, closing: "").joined())
                            } else {
                                Text(email.body)
                            }
                        }
                        .font(.body)
                        .padding(.top, 6)
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)

            VStack(spacing: 12) {
                Button {
                    viewModel.proofread()
                } label: {
                    Group {
                        if viewModel.proofreadLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.bubble")
                        }
                    }
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .shadow(radius: 4, y: 2)
                }
                .disabled(viewModel.proofreadLoading)
                .accessibilityIdentifier("emailProofreadButton")

                Button {
                    viewModel.summarize()
                } label: {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(radius: 6, y: 2)
                }
            }
            .padding(20)

            if viewModel.isSummaryBubbleVisible {
                SummaryBubble(
                    text: viewModel.streamingSummary,
                    isStreaming: viewModel.isStreaming,
                    error: viewModel.streamError,
                    mode: viewModel.summaryMode,
                    onSelectMode: { viewModel.regenerateSummary(mode: $0) },
                    onClose: { viewModel.dismissSummaryBubble() },
                    onResetEngine: { viewModel.resetEngine() }
                )
                .padding(.trailing, 20)
                .padding(.bottom, 132) // clear both floating buttons
            }
        }
        .navigationTitle(email?.subject ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.resetOnQuit()
        }
    }
}
