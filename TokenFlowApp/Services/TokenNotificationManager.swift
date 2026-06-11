import Foundation
import UserNotifications

@MainActor
final class TokenNotificationManager {
    static let shared = TokenNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let thresholds = stride(from: 10, through: 90, by: 10).map(Double.init)

    private init() {}

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(_ snapshot: TokenFlowSnapshot) {
        requestAuthorization()

        evaluateSession(snapshot.currentSession)
        evaluateWeek(snapshot.weekly)
    }

    private func evaluateSession(_ session: SessionUsageSnapshot) {
        guard session.id != SessionUsageSnapshot.empty.id else { return }

        let usedPercent: Double
        if let limit = session.primaryLimit {
            usedPercent = limit.usedPercent
        } else {
            guard session.contextWindow > 0 else { return }
            usedPercent = Double(session.total.total) / Double(session.contextWindow) * 100
        }

        let resetKey = session.primaryLimit?.resetsAt.map { ISO8601DateFormatter().string(from: $0) } ?? "no-reset"
        let key = "notifications.session.\(session.id).\(resetKey)"
        let title = "Session at %@"
        let body = "TokenFlow is tracking \(DisplayFormatters.tokens(session.total.total)) tokens in this session."

        notifyIfNeeded(key: key, usedPercent: usedPercent, title: title, body: body)
    }

    private func evaluateWeek(_ weekly: WeeklyUsageSnapshot) {
        guard let limit = weekly.limit else { return }

        let resetKey = limit.resetsAt.map { ISO8601DateFormatter().string(from: $0) } ?? "no-reset"
        let key = "notifications.week.\(resetKey)"
        let title = "Week at %@"
        let body = "TokenFlow is tracking \(DisplayFormatters.tokens(weekly.totalTokens)) tokens this week."

        notifyIfNeeded(key: key, usedPercent: limit.usedPercent, title: title, body: body)
    }

    private func notifyIfNeeded(key: String, usedPercent: Double, title: String, body: String) {
        let current = min(max(usedPercent, 0), 100)
        let crossed = thresholds.filter { $0 <= current }.max() ?? 0

        if defaults.object(forKey: key) == nil {
            defaults.set(crossed, forKey: key)
            return
        }

        let previous = defaults.double(forKey: key)
        guard crossed > previous else { return }

        let pending = thresholds.filter { $0 > previous && $0 <= crossed }
        defaults.set(crossed, forKey: key)

        for threshold in pending {
            send(title: String(format: title, "\(Int(threshold)) %"), body: body, threshold: threshold, key: key)
        }
    }

    private func send(title: String, body: String, threshold: Double, key: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "tokenflow.\(key).\(Int(threshold))",
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
