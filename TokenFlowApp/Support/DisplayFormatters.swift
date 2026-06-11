import Foundation

enum DisplayFormatters {
    private static let exactNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()

    static func tokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1f M", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.0f k", Double(value) / 1_000)
        }
        return "\(value)"
    }

    static func exactTokens(_ value: Int) -> String {
        exactNumberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percent(_ value: Double) -> String {
        "\(Int(value.rounded())) %"
    }

    static func tokenSharePercent(_ value: Double) -> String {
        if value > 0, value < 1 {
            return String(format: "%.1f %%", value)
        }
        return percent(value)
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

    static func dayAndTime(_ value: Date?) -> String {
        guard let value else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE 'at' h:mm a"
        return formatter.string(from: value)
    }
}
