import Foundation

/// Splits an email body into its opening greeting, the substantive middle paragraphs, and the
/// closing sign-off — so the Proofreader can be pointed at just the middle, leaving "Hi team," and
/// "Thanks,\nAlex" untouched. Every seeded email follows a "Greeting,\n\n<paragraphs>\n\nClosing,\nName"
/// shape (paragraphs separated by a blank line); anything that doesn't fit that shape (fewer than
/// 3 paragraphs) is treated as all middle, so the whole thing still gets proofread rather than
/// silently doing nothing.
struct EmailBodyParts: Equatable {
    let greeting: String
    let middle: String
    let closing: String

    /// Recombines the parts back into a single body string, joining only the non-empty parts.
    func joined() -> String {
        [greeting, middle, closing].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}

func splitEmailBody(_ body: String) -> EmailBodyParts {
    let paragraphs = body.components(separatedBy: "\n\n")
    guard paragraphs.count >= 3 else {
        return EmailBodyParts(greeting: "", middle: body, closing: "")
    }
    let greeting = paragraphs[0]
    let closing = paragraphs[paragraphs.count - 1]
    let middle = paragraphs[1..<(paragraphs.count - 1)].joined(separator: "\n\n")
    return EmailBodyParts(greeting: greeting, middle: middle, closing: closing)
}
