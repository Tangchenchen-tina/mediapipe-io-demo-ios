import Foundation

enum TextSanitizer {
    /// Strips characters that have no business reaching a text model: Private Use Area code
    /// points (U+E000–U+F8FF — dingbat/symbol-font glyphs like a Wingdings bullet, meaningless
    /// outside their source font) and other non-printable control characters. Returns `nil` if
    /// what's left isn't worth sending to the model at all — e.g. a PDF signature page that's
    /// almost entirely blank lines and underscores. Real generation failures should still surface
    /// as real errors; this only screens out input that was never going to produce a sensible
    /// result and, per real-device reports, can destabilize the on-device engine outright.
    static func sanitizeForModel(_ text: String) -> String? {
        let cleaned = text.unicodeScalars.filter { scalar in
            if (0xE000...0xF8FF).contains(scalar.value) { return false }
            if scalar.properties.generalCategory == .control && scalar != "\n" && scalar != "\t" { return false }
            return true
        }
        let result = String(String.UnicodeScalarView(cleaned))
        let meaningfulCount = result.filter { $0.isLetter || $0.isNumber }.count
        guard meaningfulCount >= 20 else { return nil }
        return result
    }
}
