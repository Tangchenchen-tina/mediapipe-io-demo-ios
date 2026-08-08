import CoreImage
import Foundation
import MediaPipeTasksVision
import UIKit

/// Real `InteractiveSegmenter` (from `MediaPipeTasksVision`), backed by
/// `interactive_segmentation.task` — verified against the local
/// `mediapipe-samples/examples/interactive_segmentation/ios` reference before writing this. Runs
/// on the GPU delegate (the reference app's default too): this is a split model (an expensive
/// per-image encoder pass in `setImage`, a cheap per-stroke decoder pass in `segment`), and GPU
/// makes the decoder pass fast enough to feel live as the user draws.
///
/// Same two critical details as the text engines (see `MediaPipeTextSummarizerEngine`'s doc
/// comment): native calls run via `Task.detached` so a slow/stuck call can't block `reset()`
/// forever, since actors serialize their isolated work. Unlike the text engines, `InteractiveSegmenter`
/// doesn't expose a `close()` — dropping the reference is the only teardown this SDK offers.
actor MediaPipeInteractiveSegmenterEngine: InteractiveSegmenterEngine {
    private var segmenter: InteractiveSegmenter?
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    func setImage(_ image: UIImage) async throws {
        let engine = try segmenterInstance()
        let mpImage = try MPImage(uiImage: image)
        let engineBox = UncheckedSendableBox(engine)
        let imageBox = UncheckedSendableBox(mpImage)
        try await Task.detached {
            try engineBox.value.set(image: imageBox.value)
        }.value
    }

    func segment(strokes: [StickerStroke]) async throws -> CGImage? {
        let engine = try segmenterInstance()
        let mpStrokes = strokes.map(Self.mediaPipeStroke)
        let engineBox = UncheckedSendableBox(engine)
        let strokesBox = UncheckedSendableBox(mpStrokes)
        // `MPImage` isn't Sendable, so it can't cross back out of the detached task directly —
        // box it the same way the input arguments are boxed going in. Note: despite the ObjC
        // header marking the return `nullable`, the "nullable return + NSError** param" ObjC
        // convention bridges to a non-optional throwing Swift return (nil-on-failure folds into
        // `throws`) — confirmed by the real compiler, not assumed.
        let resultBox = try await Task.detached {
            UncheckedSendableBox(try engineBox.value.segment(strokes: strokesBox.value))
        }.value
        return try await cgImage(from: resultBox.value)
    }

    func reset() {
        segmenter = nil
    }

    private func segmenterInstance() throws -> InteractiveSegmenter {
        if let segmenter { return segmenter }
        guard let modelPath = Bundle.main.path(forResource: "interactive_segmentation", ofType: "task") else {
            throw MediaPipeEngineError.modelNotFound("interactive_segmentation.task")
        }
        let options = InteractiveSegmenterOptions()
        options.baseOptions.modelAssetPath = modelPath
        #if targetEnvironment(simulator)
        // The Simulator's Metal stack can't reliably back the GPU delegate's CVMetalTextureCache
        // for ML tensor conversion — confirmed by a real crash (SIGABRT, aborted from inside
        // MediaPipe's own `DrishtiMetalHelper`/`TensorConverterCalculator::ProcessGPU`, not a
        // guess). CPU works fine there; GPU is still used on real devices, where this is a real
        // limitation of Simulator's Metal translation layer rather than of the device GPU path.
        options.baseOptions.delegate = .CPU
        #else
        options.baseOptions.delegate = .GPU
        #endif
        let newSegmenter = try InteractiveSegmenter(options: options)
        segmenter = newSegmenter
        return newSegmenter
    }

    /// Mirrors the reference app's `updateMaskUI` — the mask can come back as any of MPImage's
    /// three backing source types, so all three need handling rather than assuming one.
    private func cgImage(from mpImage: MPImage) async throws -> CGImage? {
        switch mpImage.imageSourceType {
        case .image:
            return mpImage.image?.cgImage
        case .pixelBuffer:
            guard let pixelBuffer = mpImage.pixelBuffer else { return nil }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let rect = CGRect(
                x: 0, y: 0,
                width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)
            )
            let contextBox = UncheckedSendableBox(ciContext)
            let imageBox = UncheckedSendableBox(ciImage)
            return await Task.detached {
                contextBox.value.createCGImage(imageBox.value, from: rect)
            }.value
        case .sampleBuffer:
            return nil
        default:
            // `MPImageSourceType` is an `NS_TYPED_ENUM` (bridges as a struct with static members,
            // not a true Swift enum), so it isn't exhaustively switchable — this covers any case
            // added in a future SDK version.
            return nil
        }
    }

    private static func mediaPipeStroke(_ stroke: StickerStroke) -> Stroke {
        let keypoints = stroke.points.map {
            NormalizedKeypoint(location: CGPoint(x: $0.x, y: $0.y), label: nil, score: 0)
        }
        return Stroke(points: keypoints, brushMode: stroke.brushMode.mediaPipeBrushMode, isCompleted: true)
    }
}

private extension StickerBrushMode {
    var mediaPipeBrushMode: BrushMode {
        switch self {
        case .positive: return .positive
        case .negative: return .negative
        }
    }
}
