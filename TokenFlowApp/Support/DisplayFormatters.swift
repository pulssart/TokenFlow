import Foundation

enum DisplayFormatters {
    static func tokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1f M", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.0f k", Double(value) / 1_000)
        }
        return "\(value)"
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded())) %"
    }

    static func date(_ value: Date?) -> String {
        guard let value else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: value, relativeTo: .now)
    }

    static func absoluteDate(_ value: Date?) -> String {
        guard let value else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: value)
    }
}
