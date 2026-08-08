import Foundation

enum SummaryMode: Equatable {
    case tldr
    case keyPoints
}

protocol TextSummarizerEngine: Sendable {
    func summarize(text: String, mode: SummaryMode) async throws -> String

    /// Same summarization, but yielding chunks as MediaPipe generates them — backs the Archive
    /// section's floating-button popup, which fills in as text streams rather than waiting for
    /// the whole summary at once.
    func summarizeStreaming(text: String, mode: SummaryMode) async -> AsyncThrowingStream<String, Error>
}
