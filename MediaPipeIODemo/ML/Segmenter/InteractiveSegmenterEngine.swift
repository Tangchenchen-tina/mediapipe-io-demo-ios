import CoreGraphics
import Foundation
import UIKit

enum StickerBrushMode {
    case positive
    case negative
}

/// A single normalized (0...1) point within a stroke — kept app-owned rather than reusing
/// MediaPipe's `NormalizedKeypoint` directly, matching the rest of this codebase's convention of
/// keeping MediaPipe SDK types behind the engine boundary (see `SummaryMode` vs
/// `TextSummarizerMode`).
struct StickerStrokePoint {
    let x: Double
    let y: Double
}

struct StickerStroke {
    let points: [StickerStrokePoint]
    let brushMode: StickerBrushMode
}

protocol InteractiveSegmenterEngine: Sendable {
    /// Runs the encoder pass on a new image (the "expensive" half of the split model) — must be
    /// called at least once before `segment(strokes:)`, and again whenever the source image
    /// changes.
    func setImage(_ image: UIImage) async throws

    /// Runs the decoder pass (cheap, per-interaction) against the currently-set image using the
    /// given strokes. Returns the raw segmentation mask — the caller (see `StickerCutout`)
    /// resizes it to the source image's exact pixel dimensions before compositing, since the
    /// model's mask resolution doesn't necessarily match the input image's.
    func segment(strokes: [StickerStroke]) async throws -> CGImage?

    /// Discards the cached engine instance so the next call creates a fresh one — see
    /// `TextSummarizerEngine.reset` for why this matters after an error.
    func reset() async
}
