import Foundation

private func date(fromEpochMillis millis: Int64) -> Date {
    Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
}

/// Day-level relative time for list rows, e.g. "3 hr. ago", "Yesterday" — matches the Android
/// sibling app's `formatRelativeTime`.
func formatRelativeTime(_ epochMillis: Int64) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date(fromEpochMillis: epochMillis), relativeTo: Date())
}

/// Clock time for a single message bubble, e.g. "10:32 AM" — distinct from the day-level
/// `formatRelativeTime` used on list rows.
func formatTime(_ epochMillis: Int64) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date(fromEpochMillis: epochMillis))
}
