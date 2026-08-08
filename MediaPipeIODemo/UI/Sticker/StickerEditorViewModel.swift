import CoreGraphics
import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class StickerEditorViewModel {
    let inputImage: UIImage
    private let repository: StickerRepository

    var strokes: [StickerStroke] = []
    var brushMode: StickerBrushMode = .positive
    var maskImage: UIImage?
    var isBusy = false
    var statusMessage = "Preparing image…"
    var errorMessage: String?
    var didSave = false

    private var maskCGImage: CGImage?
    private var segmentTask: Task<Void, Never>?

    init(image: UIImage, repository: StickerRepository) {
        self.inputImage = image
        self.repository = repository
    }

    func start() async {
        isBusy = true
        errorMessage = nil
        do {
            try await repository.setImage(inputImage)
            statusMessage = "Draw on the subject to select it"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Couldn't prepare this image"
        }
        isBusy = false
    }

    /// Appends a completed stroke (positive or negative, per the current brush mode) and re-runs
    /// segmentation — mirrors the reference app's "segment on every completed stroke" behavior, so
    /// the mask preview updates live as you refine the selection.
    func addStroke(points: [StickerStrokePoint]) {
        guard !points.isEmpty else { return }
        strokes.append(StickerStroke(points: points, brushMode: brushMode))
        runSegmentation()
    }

    /// Removes just the last stroke — for the common "oops, that one dot/drag was wrong" case,
    /// where clearing everything and starting over is more than you actually need.
    func undoLastStroke() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        if strokes.isEmpty {
            clearStrokes()
        } else {
            runSegmentation()
        }
    }

    func clearStrokes() {
        segmentTask?.cancel()
        strokes.removeAll()
        maskImage = nil
        maskCGImage = nil
        statusMessage = "Draw on the subject to select it"
    }

    private func runSegmentation() {
        segmentTask?.cancel()
        isBusy = true
        statusMessage = "Segmenting…"
        let currentStrokes = strokes
        segmentTask = Task {
            do {
                let mask = try await repository.segment(strokes: currentStrokes)
                if Task.isCancelled { return }
                maskCGImage = mask
                maskImage = mask.map { UIImage(cgImage: $0) }
                statusMessage = "Ready"
            } catch {
                if Task.isCancelled { return }
                errorMessage = error.localizedDescription
                statusMessage = "Segmentation error"
                // Deliberately not auto-resetting here (unlike the text engines): the segmenter
                // is a two-phase split model, and a reset also wipes the encoder pass `setImage`
                // already ran — recovering needs re-running that too, which `resetEngine()` below
                // does deliberately rather than silently, since it takes a moment.
            }
            isBusy = false
        }
    }

    /// Manual escape hatch — discards the cached engine (see `InteractiveSegmenterEngine.reset`)
    /// and re-runs the encoder pass, so a stuck/broken segmenter is actually usable again
    /// afterward rather than just reset into a state that immediately fails the next segment call.
    func resetEngine() {
        segmentTask?.cancel()
        isBusy = true
        errorMessage = nil
        statusMessage = "Resetting engine…"
        Task {
            await repository.resetSegmenterEngine()
            do {
                try await repository.setImage(inputImage)
                statusMessage = "Draw on the subject to select it"
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = "Couldn't prepare this image"
            }
            isBusy = false
        }
    }

    func saveSticker() {
        guard let maskCGImage else { return }
        let positivePoints = strokes.filter { $0.brushMode == .positive }.flatMap(\.points)
        do {
            try repository.saveSticker(image: inputImage, mask: maskCGImage, positivePoints: positivePoints)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
