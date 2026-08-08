import Foundation

/// Resolves a `Sticker` record to its transparent-PNG file on disk — mirrors `DocumentLocator`'s
/// "app-owned files live in their own Documents subfolder" pattern.
enum StickerLocator {
    static func url(for sticker: Sticker) -> URL {
        stickersDirectory.appendingPathComponent(sticker.fileName)
    }

    static var stickersDirectory: URL {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stickers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
