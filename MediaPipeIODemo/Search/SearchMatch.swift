import Foundation

struct SearchMatch: Identifiable, Equatable {
    let id: String
    let title: String
    let snippet: String
    let similarity: Float
}
