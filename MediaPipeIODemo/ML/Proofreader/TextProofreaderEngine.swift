import Foundation

protocol TextProofreaderEngine: Sendable {
    /// Just the corrected string — deliberately not surfacing per-correction metadata, since the
    /// UI renders its own diff (see `WordDiff.swift`) rather than depending on the SDK's
    /// correction-list shape directly.
    func proofread(text: String) async throws -> String

    /// Yields correction text incrementally as the model generates it, mirroring
    /// `TextSummarizerEngine.summarizeStreaming`.
    func proofreadStreaming(text: String) async -> AsyncThrowingStream<String, Error>

    /// Discards the cached engine instance so the next call creates a fresh one — see
    /// `TextSummarizerEngine.reset` for why this matters after an error.
    func reset() async
}
