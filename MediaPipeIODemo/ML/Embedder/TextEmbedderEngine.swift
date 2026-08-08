import Foundation

protocol TextEmbedderEngine: Sendable {
    func embed(text: String) async throws -> [Float]
}
