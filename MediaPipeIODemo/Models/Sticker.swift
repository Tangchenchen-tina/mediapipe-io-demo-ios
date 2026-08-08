import Foundation
import SwiftData

/// A saved sticker cutout — the actual transparent PNG bytes live on disk (see
/// `StickerLocator`), this just tracks metadata for the gallery grid.
@Model
final class Sticker {
    @Attribute(.unique) var id: String
    var fileName: String
    var createdAtMillis: Int64

    init(id: String, fileName: String, createdAtMillis: Int64) {
        self.id = id
        self.fileName = fileName
        self.createdAtMillis = createdAtMillis
    }
}
