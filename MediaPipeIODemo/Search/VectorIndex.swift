import Foundation

/// Cosine similarity between two embedding vectors, in [-1, 1]. Computed from scratch rather than
/// relying on the embedder having pre-normalized its output — see the Android sibling app's
/// `ml/README.md` for the same reasoning; kept identical here for behavioral parity.
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    precondition(a.count == b.count, "Embedding size mismatch: \(a.count) vs \(b.count)")
    var dot: Float = 0
    var normA: Float = 0
    var normB: Float = 0
    for i in 0..<a.count {
        dot += a[i] * b[i]
        normA += a[i] * a[i]
        normB += b[i] * b[i]
    }
    guard normA > 0, normB > 0 else { return 0 }
    return dot / (normA.squareRoot() * normB.squareRoot())
}
