import Foundation
import SwiftData

enum MessageSender: String, Codable {
    case me
    case other
}

@Model
final class ChatThread {
    @Attribute(.unique) var id: String
    var title: String
    var emoji: String
    var lastUpdatedMillis: Int64
    var lastMessagePreview: String

    init(id: String, title: String, emoji: String, lastUpdatedMillis: Int64, lastMessagePreview: String) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.lastUpdatedMillis = lastUpdatedMillis
        self.lastMessagePreview = lastMessagePreview
    }
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: String
    var threadId: String
    var senderRaw: String
    var text: String
    var timestampMillis: Int64

    var sender: MessageSender {
        get { MessageSender(rawValue: senderRaw) ?? .other }
        set { senderRaw = newValue.rawValue }
    }

    init(id: String, threadId: String, sender: MessageSender, text: String, timestampMillis: Int64) {
        self.id = id
        self.threadId = threadId
        self.senderRaw = sender.rawValue
        self.text = text
        self.timestampMillis = timestampMillis
    }
}
