import Foundation

enum RepositoryError: LocalizedError {
    case notFound
    case stickerCutoutFailed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Item not found."
        case .stickerCutoutFailed:
            return "Couldn't cut out a sticker from this image."
        }
    }
}
