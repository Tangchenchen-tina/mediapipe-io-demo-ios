import PDFKit
import SwiftUI

/// Which interaction the Archive document viewer is currently in — mirrors the tab-mode toggle
/// at the top of the screen.
enum ArchiveViewMode: String, CaseIterable, Identifiable {
    case preview = "Preview"
    case select = "Select"
    case selectWholePage = "Select Page"

    var id: String { rawValue }
}

/// Real `PDFView` (PDFKit), not a custom page-by-page image renderer — gives continuous vertical
/// scrolling and native drag-to-select text selection for free, both real PDFKit capabilities
/// rather than anything built from scratch.
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let mode: ArchiveViewMode
    let onSelectionChanged: (String?) -> Void

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemBackground

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionDidChange),
            name: .PDFViewSelectionChanged,
            object: view
        )

        // The real, user-driven trigger for "Select Page": tap the page you want, that page gets
        // selected and highlighted. Disabled outside `.selectWholePage` so it can't intercept
        // taps PDFKit itself handles (e.g. following a link) in the other two modes.
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tapGesture.isEnabled = mode == .selectWholePage
        view.addGestureRecognizer(tapGesture)
        context.coordinator.tapGesture = tapGesture

        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.onSelectionChanged = onSelectionChanged
        context.coordinator.mode = mode
        context.coordinator.tapGesture?.isEnabled = mode == .selectWholePage

        switch mode {
        case .preview:
            uiView.clearSelection()
            context.coordinator.clearPageHighlight(in: uiView)
            onSelectionChanged(nil)
        case .select:
            // Don't rely solely on the `.PDFViewSelectionChanged` notification firing in time —
            // re-sync directly from the live view's selection on every update pass too, so the
            // "Summarize" button reliably shows up even if a notification got missed or arrived
            // out of order relative to this render.
            context.coordinator.clearPageHighlight(in: uiView)
            onSelectionChanged(uiView.currentSelection?.string)
        case .selectWholePage:
            break // purely tap-driven now — see `Coordinator.handleTap`.
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionChanged: onSelectionChanged, mode: mode)
    }

    @MainActor
    final class Coordinator: NSObject {
        var onSelectionChanged: (String?) -> Void
        var mode: ArchiveViewMode
        weak var tapGesture: UITapGestureRecognizer?

        private static let highlightColor = UIColor.systemBlue
        private static let highlightMaxAlpha: CGFloat = 0.25
        private var highlightAnnotation: PDFAnnotation?
        private weak var highlightedPage: PDFPage?
        private var highlightAnimationTask: Task<Void, Never>?

        init(onSelectionChanged: @escaping (String?) -> Void, mode: ArchiveViewMode) {
            self.onSelectionChanged = onSelectionChanged
            self.mode = mode
        }

        @objc func selectionDidChange(_ notification: Notification) {
            guard mode == .select, let view = notification.object as? PDFView else { return }
            onSelectionChanged(view.currentSelection?.string)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard mode == .selectWholePage, let view = gesture.view as? PDFView else { return }
            let location = gesture.location(in: view)
            guard let page = view.page(for: location, nearest: true) else { return }
            let selection = page.selection(for: page.bounds(for: .mediaBox))
            onSelectionChanged(selection?.string)
            showPageHighlight(page, in: view)
        }

        /// A fixed, solid light-blue rectangle over the whole page — not PDFKit's native
        /// text-selection highlight, which only tints the actual text glyphs/lines and looks
        /// patchy over whitespace-heavy pages. Fades in via a real `PDFAnnotation` (so it scrolls
        /// naturally with the page, unlike a plain overlay `UIView` positioned in view-space).
        private func showPageHighlight(_ page: PDFPage, in view: PDFView) {
            highlightAnimationTask?.cancel()
            clearPageHighlight(in: view)

            let annotation = PDFAnnotation(bounds: page.bounds(for: .mediaBox), forType: .highlight, withProperties: nil)
            annotation.color = Self.highlightColor.withAlphaComponent(0)
            page.addAnnotation(annotation)
            highlightAnnotation = annotation
            highlightedPage = page

            highlightAnimationTask = Task { @MainActor in
                let steps = 10
                for step in 1...steps {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 16_000_000)
                    let alpha = Self.highlightMaxAlpha * CGFloat(step) / CGFloat(steps)
                    annotation.color = Self.highlightColor.withAlphaComponent(alpha)
                    view.annotationsChanged(on: page)
                }
            }
        }

        func clearPageHighlight(in view: PDFView) {
            highlightAnimationTask?.cancel()
            guard let annotation = highlightAnnotation, let page = highlightedPage else { return }
            page.removeAnnotation(annotation)
            view.annotationsChanged(on: page)
            highlightAnnotation = nil
            highlightedPage = nil
        }
    }
}
