import Foundation
import UserNotifications

@MainActor
final class TokenNotificationManager {
    static let shared = TokenNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private let storagePrefix = "notifications.v2"
    private let standardThresholds = stride(from: 10, through: 90, by: 10).map(Double.init)
    private let sessionThresholds = stride(from: 10, through: 100, by: 10).map(Double.init)

    private init() {}

    func requestAuthorization() {
        guard notificationsEnabled else { return }

        Task {
            _ = await ensureAuthorization()
        }
    }

    func evaluate(_ snapshot: TokenFlowSnapshot) async {
        guard notificationsEnabled else { return }
        guard await ensureAuthorization() else { return }

        await evaluateSession(snapshot.currentSession)
        await evaluateWeek(snapshot.weekly)
    }

    private func evaluateSession(_ session: SessionUsageSnapshot) async {
        guard session.id != SessionUsageSnapshot.empty.id else { return }

        let usedPercent: Double
        if let limit = session.primaryLimit {
            usedPercent = limit.usedPercent
        } else {
            guard session.contextWindow > 0 else { return }
            usedPercent = Double(session.total.total) / Double(session.contextWindow) * 100
        }

        let resetKey = session.primaryLimit?.resetsAt.map { ISO8601DateFormatter().string(from: $0) } ?? "no-reset"
        let key = "\(storagePrefix).session.\(session.id).\(resetKey)"

        await notifyIfNeeded(key: key, usedPercent: usedPercent, thresholds: sessionThresholds) { threshold in
            if threshold >= 100 {
                let resetText = DisplayFormatters.dayAndTime(session.primaryLimit?.resetsAt)
                return NotificationCopy(
                    title: "Session exhausted",
                    body: "This Codex session has reached its token limit. Next reset: \(resetText)."
                )
            }

            return NotificationCopy(
                title: "Session at \(Int(threshold)) %",
                body: "TokenFlow is tracking \(DisplayFormatters.tokens(session.total.total)) tokens in this session."
            )
        }
    }

    private func evaluateWeek(_ weekly: WeeklyUsageSnapshot) async {
        guard let limit = weekly.limit else { return }

        let resetKey = limit.resetsAt.map { ISO8601DateFormatter().string(from: $0) } ?? "no-reset"
        let key = "\(storagePrefix).week.\(resetKey)"

        await notifyIfNeeded(key: key, usedPercent: limit.usedPercent, thresholds: standardThresholds) { threshold in
            NotificationCopy(
                title: "Week at \(Int(threshold)) %",
                body: "TokenFlow is tracking \(DisplayFormatters.tokens(weekly.totalTokens)) tokens this week."
            )
        }
    }

    private func notifyIfNeeded(
        key: String,
        usedPercent: Double,
        thresholds: [Double],
        copy: (Double) -> NotificationCopy
    ) async {
        let current = min(max(usedPercent, 0), 100)
        let crossed = thresholds.filter { $0 <= current }.max() ?? 0
        let previous = defaults.object(forKey: key) as? Double ?? max(crossed - 10, 0)
        guard crossed > previous else { return }

        let pending = thresholds.filter { $0 > previous && $0 <= crossed }
        defaults.set(crossed, forKey: key)

        for threshold in pending {
            let notificationCopy = copy(threshold)
            await send(title: notificationCopy.title, body: notificationCopy.body, threshold: threshold, key: key)
        }
    }

    private func send(title: String, body: String, threshold: Double, key: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "tokenflow.\(key).\(Int(threshold))",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func ensureAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private var notificationsEnabled: Bool {
        defaults.object(forKey: AppPreferenceKeys.enableNotifications) as? Bool ?? true
    }
}

private struct NotificationCopy {
    var title: String
    var body: String
}
