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
actor MediaPipeTextSummarizerEngine: TextSummarizerEngine {
    private var summarizer: TextSummarizer?
    private var loadedMode: SummaryMode?

    func summarize(text: String, mode: SummaryMode) async throws -> String {
        let engine = try summarizer(for: mode)
        return try engine.summarize(text: text).summary
    }

    func summarizeStreaming(text: String, mode: SummaryMode) async -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let engine = try await self.summarizer(for: mode)
                    try engine.summarizeStreaming(text: text) { result, error in
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
