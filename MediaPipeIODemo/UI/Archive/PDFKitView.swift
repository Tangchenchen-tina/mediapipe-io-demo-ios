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
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageDidChange),
            name: .PDFViewPageChanged,
            object: view
        )
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        context.coordinator.onSelectionChanged = onSelectionChanged
        context.coordinator.mode = mode

        switch mode {
        case .preview:
            uiView.clearSelection()
        case .select:
            break // leave whatever the user has manually drag-selected in place
        case .selectWholePage:
            selectCurrentPage(in: uiView)
        }
    }

    private func selectCurrentPage(in view: PDFView) {
        guard let page = view.currentPage else { return }
        let selection = page.selection(for: page.bounds(for: .mediaBox))
        view.setCurrentSelection(selection, animate: false)
        onSelectionChanged(selection?.string)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionChanged: onSelectionChanged, mode: mode, selectWholePage: selectCurrentPage)
    }

    @MainActor
    final class Coordinator: NSObject {
        var onSelectionChanged: (String?) -> Void
        var mode: ArchiveViewMode
        let selectWholePage: (PDFView) -> Void

        init(onSelectionChanged: @escaping (String?) -> Void, mode: ArchiveViewMode, selectWholePage: @escaping (PDFView) -> Void) {
            self.onSelectionChanged = onSelectionChanged
            self.mode = mode
            self.selectWholePage = selectWholePage
        }

        @objc func selectionDidChange(_ notification: Notification) {
            guard mode == .select, let view = notification.object as? PDFView else { return }
            onSelectionChanged(view.currentSelection?.string)
        }

        @objc func pageDidChange(_ notification: Notification) {
            guard mode == .selectWholePage, let view = notification.object as? PDFView else { return }
            selectWholePage(view)
        }
    }
}
