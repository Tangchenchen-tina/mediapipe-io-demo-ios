import Foundation

enum RepositoryError: LocalizedError {
    case notFound

    var errorDescription: String? {
        "Item not found."
    }
}
