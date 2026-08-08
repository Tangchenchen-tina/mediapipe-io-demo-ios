import Foundation
import PDFKit
import UIKit

/// Renders archive PDF pages for on-screen display. PDFKit's `PDFPage.thumbnail(of:for:)` does
/// the rasterizing directly — no manual `ParcelFileDescriptor`/offset handling needed here, unlike
/// the Android sibling app's `PdfPageRenderer` (which had to work around `AssetManager.openFd()`
/// handing back a descriptor into the containing APK rather than a standalone file).
struct PdfPageRenderer {
    func renderPage(_ document: ArchiveDocument, pageIndex: Int, targetWidth: CGFloat = 720) -> UIImage? {
        guard
            let url = DocumentLocator.url(for: document),
            let pdf = PDFDocument(url: url),
            let page = pdf.page(at: pageIndex)
        else {
            return nil
        }
        let pageRect = page.bounds(for: .mediaBox)
        guard pageRect.width > 0 else { return nil }
        let scale = targetWidth / pageRect.width
        let size = CGSize(width: targetWidth, height: pageRect.height * scale)
        return page.thumbnail(of: size, for: .mediaBox)
    }
}
