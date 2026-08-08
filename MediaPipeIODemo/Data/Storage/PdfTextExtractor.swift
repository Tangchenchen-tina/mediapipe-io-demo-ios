import Foundation
import PDFKit

/// Real text-layer extraction (not OCR) from archive PDFs, via Apple's PDFKit — the iOS
/// counterpart to the Android sibling app's PDFBox-Android-based extractor. Used two ways:
/// `extractFirstPages` scans just the first couple of pages at index time (enough to make a paper
/// findable by meaning without reading a whole large PDF up front); `extractPage` pulls a single
/// page's text on demand for the "select a page, summarize it" viewer action.
struct PdfTextExtractor {
    private static let pagesToScanAtInit = 2

    func extractFirstPages(_ document: ArchiveDocument, pageCount: Int = PdfTextExtractor.pagesToScanAtInit) -> String {
        extractPageRange(document, startPage: 0, endPage: pageCount - 1)
    }

    func extractPage(_ document: ArchiveDocument, pageIndex: Int) -> String {
        extractPageRange(document, startPage: pageIndex, endPage: pageIndex)
    }

    func pageCount(_ document: ArchiveDocument) -> Int {
        guard let url = DocumentLocator.url(for: document), let pdf = PDFDocument(url: url) else { return 1 }
        return max(1, pdf.pageCount)
    }

    private func extractPageRange(_ document: ArchiveDocument, startPage: Int, endPage: Int) -> String {
        guard let url = DocumentLocator.url(for: document), let pdf = PDFDocument(url: url), pdf.pageCount > 0 else {
            return ""
        }
        let lastPage = pdf.pageCount - 1
        let clampedStart = max(0, min(startPage, lastPage))
        let clampedEnd = max(clampedStart, min(endPage, lastPage))
        var text = ""
        for index in clampedStart...clampedEnd {
            if let page = pdf.page(at: index) {
                text += (page.string ?? "") + "\n"
            }
        }
        return text
    }
}
