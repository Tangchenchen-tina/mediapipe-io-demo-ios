import Foundation
import SwiftData

/// Where a document's PDF bytes actually live — bundled sample papers ship inside the app
/// bundle (read-only); anything the user imports via `.fileImporter` gets copied into the app's
/// Documents directory instead, since the bundle can't be written to at runtime.
enum DocumentSource: String, Codable {
    case bundled
    case imported
}

@Model
final class ArchiveDocument {
    @Attribute(.unique) var id: String
    var title: String
    var fileName: String
    var sourceRaw: String
    var pageCount: Int
    var importedAtMillis: Int64

    var source: DocumentSource {
        get { DocumentSource(rawValue: sourceRaw) ?? .bundled }
        set { sourceRaw = newValue.rawValue }
    }

    init(id: String, title: String, fileName: String, source: DocumentSource, pageCount: Int, importedAtMillis: Int64) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.sourceRaw = source.rawValue
        self.pageCount = pageCount
        self.importedAtMillis = importedAtMillis
    }
}
