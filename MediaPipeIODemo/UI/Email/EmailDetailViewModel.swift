import Foundation
import Observation

@Observable
@MainActor
final class EmailDetailViewModel {
    let emailId: String
    private let repository: EmailRepository

    var summaryLoading = false
    var proofreadLoading = false
    var errorMessage: String?

    init(emailId: String, repository: EmailRepository) {
        self.emailId = emailId
        self.repository = repository
    }

    // Results aren't held here — `summarize`/`proofread` persist to the `EmailItem` SwiftData
    // record directly, and the detail view's `@Query` picks up the change automatically, the
    // same way the Android sibling app's `observeEmail(id)` Flow does.

    func summarize(mode: SummaryMode) {
        Task {
            summaryLoading = true
            do {
                try await repository.summarize(id: emailId, mode: mode)
            } catch {
                errorMessage = error.localizedDescription
            }
            summaryLoading = false
        }
    }

    func proofread() {
        Task {
            proofreadLoading = true
            do {
                try await repository.proofread(id: emailId)
            } catch {
                errorMessage = error.localizedDescription
            }
            proofreadLoading = false
        }
    }
}
