import Foundation

protocol TextProofreaderEngine: Sendable {
    /// Just the corrected string — deliberately not surfacing per-correction metadata, since the
    /// UI renders its own diff (see `WordDiff.swift`) rather than depending on the SDK's
    /// correction-list shape directly.
    func proofread(text: String) async throws -> String
}
