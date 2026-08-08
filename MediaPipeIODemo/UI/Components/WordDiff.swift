import Foundation
import SwiftUI

/// A minimal word-level diff (classic LCS dynamic-programming table) between an original and a
/// corrected string, used to render the Proofreader's "view diff" — struck-through removals,
/// highlighted additions. Ported directly from the Android sibling app's `WordDiff.kt`; the
/// algorithm and tokenization are identical so the two apps produce the same diff for the same
/// input.
enum DiffSegment: Equatable {
    case unchanged(String)
    case removed(String)
    case added(String)

    var text: String {
        switch self {
        case .unchanged(let text), .removed(let text), .added(let text): return text
        }
    }
}

private func tokenize(_ text: String) -> [String] {
    guard !text.isEmpty else { return [] }
    var tokens: [String] = []
    var current = ""
    var currentIsWhitespace: Bool?
    for character in text {
        let isWhitespace = character.isWhitespace
        if currentIsWhitespace == nil || currentIsWhitespace == isWhitespace {
            current.append(character)
        } else {
            tokens.append(current)
            current = String(character)
        }
        currentIsWhitespace = isWhitespace
    }
    if !current.isEmpty { tokens.append(current) }
    return tokens
}

func computeWordDiff(original: String, corrected: String) -> [DiffSegment] {
    let a = tokenize(original)
    let b = tokenize(corrected)
    let n = a.count
    let m = b.count

    // dp[i][j] = length of the longest common subsequence of a[i..<n] and b[j..<m]
    var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
    if n > 0 && m > 0 {
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if a[i] == b[j] {
                    dp[i][j] = dp[i + 1][j + 1] + 1
                } else {
                    dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }
    }

    var segments: [DiffSegment] = []
    var i = 0
    var j = 0
    while i < n && j < m {
        if a[i] == b[j] {
            segments.append(.unchanged(a[i]))
            i += 1; j += 1
        } else if dp[i + 1][j] >= dp[i][j + 1] {
            segments.append(.removed(a[i]))
            i += 1
        } else {
            segments.append(.added(b[j]))
            j += 1
        }
    }
    while i < n { segments.append(.removed(a[i])); i += 1 }
    while j < m { segments.append(.added(b[j])); j += 1 }

    return mergeAdjacent(segments)
}

/// Collapses runs of the same segment type so the renderer doesn't emit one Text span per token.
private func mergeAdjacent(_ segments: [DiffSegment]) -> [DiffSegment] {
    var merged: [DiffSegment] = []
    for segment in segments {
        switch (merged.last, segment) {
        case (.unchanged(let last), .unchanged(let next)):
            merged[merged.count - 1] = .unchanged(last + next)
        case (.removed(let last), .removed(let next)):
            merged[merged.count - 1] = .removed(last + next)
        case (.added(let last), .added(let next)):
            merged[merged.count - 1] = .added(last + next)
        default:
            merged.append(segment)
        }
    }
    return merged
}

/// Renders a diff as a single `Text` — struck-through red for removals, green for additions —
/// for inline display (e.g. directly in place of an email's body once it's been proofread).
func diffText(original: String, corrected: String) -> Text {
    computeWordDiff(original: original, corrected: corrected).reduce(Text("")) { acc, segment in
        switch segment {
        case .unchanged(let text):
            return acc + Text(text)
        case .removed(let text):
            return acc + Text(text).strikethrough().foregroundColor(.red)
        case .added(let text):
            return acc + Text(text).foregroundColor(.green)
        }
    }
}
