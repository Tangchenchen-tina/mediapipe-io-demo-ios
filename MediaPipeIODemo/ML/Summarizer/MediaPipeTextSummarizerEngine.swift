import Foundation
import MediaPipeTasksText

/// Real MediaPipe Tasks Text integration — `TextSummarizer` from the `MediaPipeTasksText` pod,
/// backed by `summarization_quant_200m_2modes.litertlm` (a 200M-parameter Gemma-based model, the
/// same bundle the Android sibling app uses). Verified against the real SDK via the local
/// `mediapipe-samples/examples/text_summarizer/ios` reference before writing this.
///
/// An `actor` keeps exactly one `TextSummarizer` alive at a time and serializes access — mirrors
/// the Android engine's Mutex-guarded single-instance pattern, since the underlying model can
/// only be loaded for one mode at a time and switching modes means recreating it.
///
/// Critical detail #1: the actual native calls (`summarize`/`summarizeStreaming` on the SDK
/// object) are dispatched via `Task.detached` rather than run inline. A synchronous native call
/// that hangs or takes a long time would otherwise hold the actor's exclusive executor for its
/// entire duration — and since actors serialize all their isolated work, `reset()` would queue up
/// behind it and never run, making the "reset engine" button a no-op for exactly the case it
/// exists to handle. Detaching means `reset()` only ever needs a brief moment of isolation to swap
/// the cached reference, regardless of what any in-flight call is doing.
///
/// Critical detail #2: `reset()` also calls `close()` on the discarded instance. Just dropping our
/// Swift reference isn't enough — a runaway streaming call (observed on-device: the completion
/// handler keeps firing new chunks and never reports `done`) is still detached and running against
/// that same native object, which stays alive as long as that closure holds it, regardless of
/// whether anything is still isolated to it. `close()` is the SDK's own "shut this down" API and
/// is what actually stops the native session, rather than just abandoning our reference to it.
actor MediaPipeTextSummarizerEngine: TextSummarizerEngine {
    private var summarizer: TextSummarizer?
    private var loadedMode: SummaryMode?

    func summarize(text: String, mode: SummaryMode) async throws -> String {
        guard let sanitized = TextSanitizer.sanitizeForModel(text) else {
            throw MediaPipeEngineError.inputNotSuitable
        }
        let engine = try summarizer(for: mode)
        let box = UncheckedSendableBox(engine)
        return try await Task.detached {
            try box.value.summarize(text: sanitized).summary
        }.value
    }

    func summarizeStreaming(text: String, mode: SummaryMode) async -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let sanitized = TextSanitizer.sanitizeForModel(text) else {
                continuation.finish(throwing: MediaPipeEngineError.inputNotSuitable)
                return
            }
            Task {
                do {
                    let engine = try await self.summarizer(for: mode)
                    let box = UncheckedSendableBox(engine)
                    Task.detached {
                        do {
                            try box.value.summarizeStreaming(text: sanitized) { result, error in
                                if let error {
                                    continuation.finish(throwing: error)
                                    return
                                }
                                if let chunk = result?.chunk, !chunk.isEmpty {
                                    continuation.yield(chunk)
                                }
                                if result?.done == true {
                                    continuation.finish()
                                }
                            }
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func reset() {
        guard let old = summarizer else { return }
        summarizer = nil
        loadedMode = nil
        let box = UncheckedSendableBox(old)
        // Off the actor (and off the calling thread) so a slow/stuck close() can't turn `reset()`
        // back into the very kind of blocking call it exists to route around.
        Task.detached {
            try? box.value.close()
        }
    }

    private func summarizer(for mode: SummaryMode) throws -> TextSummarizer {
        if let summarizer, loadedMode == mode {
            return summarizer
        }
        guard let modelPath = Bundle.main.path(forResource: "summarization_quant_200m_2modes", ofType: "litertlm") else {
            throw MediaPipeEngineError.modelNotFound("summarization_quant_200m_2modes.litertlm")
        }
        let options = TextSummarizerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.mode = mode.mediaPipeMode
        let newSummarizer = try TextSummarizer(options: options)
        summarizer = newSummarizer
        loadedMode = mode
        return newSummarizer
    }
}

private extension SummaryMode {
    var mediaPipeMode: TextSummarizerMode {
        switch self {
        case .tldr: return .tldr
        case .keyPoints: return .keyPoints
        }
    }
}
