import AppKit
import Foundation

struct CodexAuthReader {
    func read() -> AuthSnapshot {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .missing
        }

        let mode = (object["auth_mode"] as? String).map(cleanMode) ?? "Codex"
        let refresh = (object["last_refresh"] as? String).flatMap(Self.parseDate)
        return AuthSnapshot(isSignedIn: true, mode: mode, lastRefresh: refresh)
    }

    func openLogin() {
        let script = """
        tell application "Terminal"
            activate
            do script "codex login"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private func cleanMode(_ raw: String) -> String {
        switch raw.lowercased() {
        case "chatgpt":
            return "ChatGPT"
        case "api":
            return "API key"
        default:
            return raw
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter.codex.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

extension ISO8601DateFormatter {
    static let codex: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
