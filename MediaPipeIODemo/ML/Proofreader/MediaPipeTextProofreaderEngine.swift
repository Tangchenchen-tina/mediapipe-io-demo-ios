import Foundation
import MediaPipeTasksText

/// Real `TextProofreader` (from `MediaPipeTasksText`), backed by `proofread_quant_200m.litertlm`
/// — verified against the local `mediapipe-samples/examples/text_proofreader/ios` reference.
/// A single instance is created lazily and reused for the app's lifetime (unlike the Summarizer,
/// there's no mode to switch, so no need to ever recreate it).
///
/// Critical details: the actual native calls are dispatched via `Task.detached` rather than run
/// inline, and `reset()` calls `close()` on the discarded instance rather than just dropping the
/// Swift reference — see `MediaPipeTextSummarizerEngine`'s doc comment for why both matter.
actor MediaPipeTextProofreaderEngine: TextProofreaderEngine {
    private var proofreader: TextProofreader?

    func proofread(text: String) async throws -> String {
        guard let sanitized = TextSanitizer.sanitizeForModel(text) else {
            throw MediaPipeEngineError.inputNotSuitable
        }
        let engine = try proofreaderInstance()
        let box = UncheckedSendableBox(engine)
        return try await Task.detached {
            try box.value.proofread(text: sanitized).proofreadText
        }.value
    }

    func proofreadStreaming(text: String) async -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let sanitized = TextSanitizer.sanitizeForModel(text) else {
                continuation.finish(throwing: MediaPipeEngineError.inputNotSuitable)
                return
            }
            Task {
                do {
                    let engine = try await self.proofreaderInstance()
                    let box = UncheckedSendableBox(engine)
                    Task.detached {
                        do {
                            try box.value.proofreadStreaming(text: sanitized) { result, error in
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
        guard let old = proofreader else { return }
        proofreader = nil
        let box = UncheckedSendableBox(old)
        // See `MediaPipeTextSummarizerEngine.reset` — just dropping the Swift reference isn't
        // enough to stop a runaway streaming call that's still detached and running against this
        // same native object; `close()` is what actually shuts the session down.
        Task.detached {
            try? box.value.close()
        }
    }

    private func proofreaderInstance() throws -> TextProofreader {
        if let proofreader { return proofreader }
        guard let modelPath = Bundle.main.path(forResource: "proofread_quant_200m", ofType: "litertlm") else {
            throw MediaPipeEngineError.modelNotFound("proofread_quant_200m.litertlm")
        }
        let newProofreader = try TextProofreader(modelPath: modelPath)
        proofreader = newProofreader
        return newProofreader
    }
}
