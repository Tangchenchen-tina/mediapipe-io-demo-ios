import Foundation
import MediaPipeTasksText

/// Real `TextProofreader` (from `MediaPipeTasksText`), backed by `proofread_quant_200m.litertlm`
/// — verified against the local `mediapipe-samples/examples/text_proofreader/ios` reference.
/// A single instance is created lazily and reused for the app's lifetime (unlike the Summarizer,
/// there's no mode to switch, so no need to ever recreate it).
actor MediaPipeTextProofreaderEngine: TextProofreaderEngine {
    private var proofreader: TextProofreader?

    func proofread(text: String) async throws -> String {
        let engine = try proofreaderInstance()
        return try engine.proofread(text: text).proofreadText
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
