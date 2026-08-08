import Foundation
import SwiftData

@Model
final class EmailItem {
    @Attribute(.unique) var id: String
    var from: String
    var to: String
    var subject: String
    var body: String
    var timestampMillis: Int64
    var proofreadBody: String?
    var summary: String?

    init(
        id: String,
        from: String,
        to: String,
        subject: String,
        body: String,
        timestampMillis: Int64,
        proofreadBody: String? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.subject = subject
        self.body = body
        self.timestampMillis = timestampMillis
        self.proofreadBody = proofreadBody
        self.summary = summary
    }
}
