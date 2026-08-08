import SwiftUI

struct StickerEditorView: View {
    @State private var viewModel: StickerEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(image: UIImage, container: AppContainer) {
        _viewModel = State(initialValue: StickerEditorViewModel(image: image, repository: container.stickerRepository))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if viewModel.isBusy {
                    ProgressView().padding(.trailing, 4)
                }
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("stickerStatusText")
                Spacer()
                Button {
                    viewModel.resetEngine()
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Reset engine")
            }
            .padding()

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GeometryReader { geometry in
                StickerDrawingCanvas(viewModel: viewModel, viewSize: geometry.size)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .background(Color(.secondarySystemBackground))
            .accessibilityIdentifier("stickerCanvas")

            VStack(spacing: 12) {
                Picker("Brush", selection: $viewModel.brushMode) {
                    Text("Positive").tag(StickerBrushMode.positive)
                    Text("Negative").tag(StickerBrushMode.negative)
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("Undo") { viewModel.undoLastStroke() }
                        .disabled(viewModel.strokes.isEmpty)
                    Button("Clear", role: .destructive) { viewModel.clearStrokes() }
                        .disabled(viewModel.strokes.isEmpty)
                    Spacer()
                    Button("Save Sticker") { viewModel.saveSticker() }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.maskImage == nil)
                }
            }
            .padding()
            .disabled(viewModel.isBusy)
        }
        // The status row and button row above have no background of their own — without an
        // opaque background on the whole screen, those areas stay SwiftUI's default transparent,
        // which (being presented in a `fullScreenCover`) let the tab bar from the view underneath
        // show through instead of a solid surface.
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle("New Sticker")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.start() }
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave { dismiss() }
        }
    }
}

/// Adapted from the local `interactive_segmentation/ios` reference app's `DrawingCanvasView` +
/// `StrokesOverlay` — same drag-gesture-to-normalized-points approach, positive/negative only
/// (this app doesn't expose the reference's third "lasso" brush mode).
private struct StickerDrawingCanvas: View {
    var viewModel: StickerEditorViewModel
    let viewSize: CGSize

    @State private var currentPoints: [StickerStrokePoint] = []

    var body: some View {
        let rect = viewModel.inputImage.size.aspectFit(in: viewSize)
        ZStack {
            Image(uiImage: viewModel.inputImage)
                .resizable()
                .scaledToFit()
                .frame(width: viewSize.width, height: viewSize.height)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in handle(value.location, in: rect) }
                        .onEnded { value in handle(value.location, in: rect, completed: true) }
                )
                .disabled(viewModel.isBusy)

            if let maskImage = viewModel.maskImage {
                Image(uiImage: maskImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: viewSize.width, height: viewSize.height)
                    .opacity(0.5)
                    .allowsHitTesting(false)
            }

            StickerStrokesOverlay(strokes: viewModel.strokes, currentPoints: currentPoints, currentBrushMode: viewModel.brushMode, rect: rect)
        }
    }

    private func handle(_ location: CGPoint, in rect: CGRect, completed: Bool = false) {
        guard rect.contains(location) else { return }
        let normalized = StickerStrokePoint(
            x: (location.x - rect.origin.x) / rect.width,
            y: (location.y - rect.origin.y) / rect.height
        )
        if let last = currentPoints.last {
            if last.x != normalized.x || last.y != normalized.y {
                currentPoints.append(normalized)
            }
        } else {
            currentPoints.append(normalized)
        }

        if completed {
            viewModel.addStroke(points: currentPoints)
            currentPoints.removeAll()
        }
    }
}

private struct StickerStrokesOverlay: View {
    let strokes: [StickerStroke]
    let currentPoints: [StickerStrokePoint]
    let currentBrushMode: StickerBrushMode
    let rect: CGRect

    var body: some View {
        ZStack {
            ForEach(Array(strokes.enumerated()), id: \.offset) { _, stroke in
                path(for: stroke.points, color: color(for: stroke.brushMode))
            }
            if !currentPoints.isEmpty {
                path(for: currentPoints, color: color(for: currentBrushMode))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func path(for points: [StickerStrokePoint], color: Color) -> some View {
        if points.count == 1, let point = points.first {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .position(denormalize(point))
        } else {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: denormalize(first))
                for point in points.dropFirst() {
                    path.addLine(to: denormalize(point))
                }
            }
            .stroke(color, lineWidth: 3)
        }
    }

    private func denormalize(_ point: StickerStrokePoint) -> CGPoint {
        CGPoint(x: rect.origin.x + point.x * rect.width, y: rect.origin.y + point.y * rect.height)
    }

    private func color(for mode: StickerBrushMode) -> Color {
        switch mode {
        case .positive: return .green
        case .negative: return .red
        }
    }
}

extension CGSize {
    /// Same "letterboxed fit" rect math the reference app uses, needed here too since strokes are
    /// drawn in the scaled/letterboxed display coordinate space but must be normalized against the
    /// image's own bounds before being sent to the segmenter.
    func aspectFit(in viewSize: CGSize) -> CGRect {
        guard width > 0, height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return CGRect(origin: .zero, size: viewSize)
        }
        let imageRatio = width / height
        let viewRatio = viewSize.width / viewSize.height
        var scale: CGFloat
        var offset = CGPoint.zero
        if imageRatio > viewRatio {
            scale = viewSize.width / width
            offset.y = (viewSize.height - height * scale) / 2.0
        } else {
            scale = viewSize.height / height
            offset.x = (viewSize.width - width * scale) / 2.0
        }
        return CGRect(x: offset.x, y: offset.y, width: width * scale, height: height * scale)
    }
}
