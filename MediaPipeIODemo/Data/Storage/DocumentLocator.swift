import Foundation

/// Resolves an `ArchiveDocument` record to the real file `URL` its PDF bytes live at — bundled
/// sample papers ship inside the app bundle; imported documents live in the app's own
/// Documents/ImportedDocuments folder (copied there at import time, since the app can't write
/// into its own read-only bundle).
enum DocumentLocator {
    static func url(for document: ArchiveDocument) -> URL? {
        switch document.source {
        case .bundled:
            let name = (document.fileName as NSString).deletingPathExtension
            let ext = (document.fileName as NSString).pathExtension
            return Bundle.main.url(forResource: name, withExtension: ext)
        case .imported:
            return importedDocumentsDirectory.appendingPathComponent(document.fileName)
        }
    }

    static var importedDocumentsDirectory: URL {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImportedDocuments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
