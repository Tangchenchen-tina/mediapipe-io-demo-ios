import Foundation
import SwiftData

/// What a stored embedding is *of* — mirrors the Android app's `EmbeddingScope`. One flat table
/// backs global search in all three sections plus local, in-thread chat search; this tag is how
/// `SemanticSearchService` filters candidates before ranking by cosine similarity.
enum EmbeddingScope: String, Codable {
    case chatThread
    case chatMessage
    case email
    case archiveDocument
}

@Model
final class EmbeddingRecord {
    @Attribute(.unique) var id: String
    var scopeRaw: String
    var parentId: String?
    var title: String
    var snippet: String
    /// The embedding vector, stored as raw bytes (4 bytes per Float32, little-endian) — SwiftData
    /// doesn't have a native `[Float]` column type, so this is the on-disk representation;
    /// `vector`/`floatValues` below convert to/from `[Float]` at the call sites.
    var vectorData: Data

    var scope: EmbeddingScope {
        get { EmbeddingScope(rawValue: scopeRaw) ?? .chatThread }
        set { scopeRaw = newValue.rawValue }
    }

    var floatValues: [Float] {
        vectorData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    init(id: String, scope: EmbeddingScope, parentId: String?, title: String, snippet: String, vector: [Float]) {
        self.id = id
        self.scopeRaw = scope.rawValue
        self.parentId = parentId
        self.title = title
        self.snippet = snippet
        self.vectorData = vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
