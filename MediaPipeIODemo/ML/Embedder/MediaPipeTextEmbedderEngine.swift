import Foundation
import MediaPipeTasksText

/// Real `TextEmbedder` (from `MediaPipeTasksText`), backed by EmbeddingGemma-300m
/// (`embedding_gemma.task`) — the same model bundle the Android sibling app uses, since MediaPipe's
/// `.task` bundle format is designed to be cross-platform. If a future SDK version rejects this
/// bundle on iOS, dropping back to `universal_sentence_encoder.tflite` (the model the local
/// `mediapipe-samples/examples/text_embedder/ios` reference ships) is a one-line change: swap the
/// `forResource`/`ofType` pair below.
actor MediaPipeTextEmbedderEngine: TextEmbedderEngine {
    // EmbeddingGemma's graph rejects input over 512 tokens (a native RET_CHECK failure). No
    // on-device tokenizer to count exactly, so this word-count cap is a conservative proxy,
    // carried over from the same limit discovered the hard way in the Android sibling app.
    private static let maxWords = 220

    private var embedder: TextEmbedder?

    func embed(text: String) async throws -> [Float] {
        let engine = try embedderInstance()
        let truncated = text
            .split(separator: " ", omittingEmptySubsequences: true)
            .prefix(Self.maxWords)
            .joined(separator: " ")
        let result = try engine.embed(text: truncated)
        guard let embedding = result.embeddingResult.embeddings.first, let values = embedding.floatEmbedding else {
            throw MediaPipeEngineError.modelNotFound("embedding result had no float embedding")
        }
        // `floatEmbedding` bridges from Objective-C as `[NSNumber]`, not `[Float]` directly.
        return values.map(\.floatValue)
    }

    private func embedderInstance() throws -> TextEmbedder {
        if let embedder { return embedder }
        guard let modelPath = Bundle.main.path(forResource: "embedding_gemma", ofType: "task") else {
            throw MediaPipeEngineError.modelNotFound("embedding_gemma.task")
        }
        let newEmbedder = try TextEmbedder(modelPath: modelPath)
        embedder = newEmbedder
        return newEmbedder
    }
}
