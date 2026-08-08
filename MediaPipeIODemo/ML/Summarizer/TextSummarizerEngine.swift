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

    /// Discards the cached engine instance so the next call creates a fresh one. Some inputs (a
    /// large/malformed page of extracted PDF text, in particular) have been observed to leave the
    /// underlying native session unusable for every subsequent call, not just the one that failed
    /// — calling this after an error is the only way to recover without restarting the app.
    func reset() async
}
