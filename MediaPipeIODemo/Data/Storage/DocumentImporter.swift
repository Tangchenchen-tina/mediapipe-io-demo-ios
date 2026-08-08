import Foundation

enum DocumentImportError: LocalizedError {
    case accessDenied
    case copyFailed(Error)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Couldn't access the selected file."
        case .copyFailed(let error):
            return "Couldn't import the file: \(error.localizedDescription)"
        }
    }
}

/// Backs the Archive section's "Import" action — driven by SwiftUI's `.fileImporter`, which lets
/// the user browse anywhere the Files app can reach, including a Mac's Desktop/Documents folders
/// when iCloud Drive desktop sync is on, or a locally mounted volume in Simulator.
struct DocumentImporter {
    /// Copies a user-picked file into the app's own Documents/ImportedDocuments folder, so it
    /// survives independent of wherever the user originally picked it from. `.fileImporter` hands
    /// back a security-scoped URL for anything outside the app sandbox, so this brackets the copy
    /// with `startAccessingSecurityScopedResource`/`stopAccessingSecurityScopedResource`.
    func importFile(from sourceURL: URL) throws -> URL {
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { sourceURL.stopAccessingSecurityScopedResource() } }
        guard didStartAccessing else { throw DocumentImportError.accessDenied }

        let destination = DocumentLocator.importedDocumentsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            throw DocumentImportError.copyFailed(error)
        }
    }
}
