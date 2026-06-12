import Foundation

struct CodexUsageReader {
    private let authReader = CodexAuthReader()
    private let calendar = Calendar(identifier: .iso8601)
    private let fileLookbackDays = 8
    private let maximumSessionFiles = 80
    private let metadataReadLimit = 64 * 1024
    private let initialTailReadLimit: UInt64 = 256 * 1024
    private let maximumTailReadLimit: UInt64 = 4 * 1024 * 1024

    func readSnapshot() throws -> TokenFlowSnapshot {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let codex = home.appendingPathComponent(".codex")
        let index = readSessionIndex(at: codex.appendingPathComponent("session_index.jsonl"))
        let files = sessionFiles(in: codex)

        var sessions: [SessionAccumulator] = []
        for file in files {
            if let session = readSessionFile(file, titles: index), session.latestEvent != nil {
                sessions.append(session)
            }
        }

        let sorted = sessions.sorted {
            ($0.latestEvent?.timestamp ?? .distantPast) > ($1.latestEvent?.timestamp ?? .distantPast)
        }

        let latest = sorted.first?.snapshot ?? .empty
        let weekly = buildWeeklySnapshot(from: sessions, latestLimit: latest.secondaryLimit)

        return TokenFlowSnapshot(
            generatedAt: .now,
            auth: authReader.read(),
            currentSession: latest,
            weekly: weekly,
            recentSessions: sorted.prefix(6).map(\.summary)
        )
    }

    private func sessionFiles(in codex: URL) -> [URL] {
        let roots = [
            codex.appendingPathComponent("sessions"),
            codex.appendingPathComponent("archived_sessions")
        ]
        let cutoff = Date().addingTimeInterval(-60 * 60 * 24 * Double(fileLookbackDays))

        let candidates = roots.flatMap { root -> [SessionFileCandidate] in
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }

            return enumerator.compactMap { item in
                guard let url = item as? URL, url.pathExtension == "jsonl" else { return nil }
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                guard let modified = values?.contentModificationDate, modified >= cutoff else { return nil }
                return SessionFileCandidate(url: url, modified: modified)
            }
        }

        return candidates
            .sorted { $0.modified > $1.modified }
            .prefix(maximumSessionFiles)
            .map(\.url)
    }

    private func readSessionIndex(at url: URL) -> [String: String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var titles: [String: String] = [:]
        for line in content.split(separator: "\n") {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = object["id"] as? String else { continue }
            titles[id] = object["thread_name"] as? String
        }
        return titles
    }

    private func readSessionFile(_ url: URL, titles: [String: String]) -> SessionAccumulator? {
        var session = SessionAccumulator(id: idFromFileName(url), title: url.deletingPathExtension().lastPathComponent, path: "")

        if let metadata = readSessionMetadata(from: url) {
            session.id = metadata.id ?? session.id
            session.title = metadata.id.flatMap { titles[$0] } ?? session.title
            session.path = metadata.path ?? session.path
        }

        if let title = titles[session.id] {
            session.title = title
        }
        session.latestEvent = readLatestTokenEvent(from: url)
        return session
    }

    private func readSessionMetadata(from url: URL) -> (id: String?, path: String?)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let data = handle.readData(ofLength: metadataReadLimit)
        let content = String(decoding: data, as: UTF8.self)

        for line in content.split(separator: "\n") {
            guard let object = parseJSONObject(line),
                  object["type"] as? String == "session_meta",
                  let payload = object["payload"] as? [String: Any] else { continue }
            return (payload["id"] as? String, payload["cwd"] as? String)
        }

        return nil
    }

    private func readLatestTokenEvent(from url: URL) -> TokenEvent? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let size = try? handle.seekToEnd(), size > 0 else { return nil }
        let cappedSize = min(size, maximumTailReadLimit)
        var bytesToRead = min(size, initialTailReadLimit)

        while bytesToRead <= cappedSize {
            let offset = size - bytesToRead
            do {
                try handle.seek(toOffset: offset)
                let data = handle.readDataToEndOfFile()
                if let event = latestTokenEvent(in: data) {
                    return event
                }
            } catch {
                return nil
            }

            if bytesToRead == cappedSize { break }
            bytesToRead = min(bytesToRead * 2, cappedSize)
        }

        return nil
    }

    private func latestTokenEvent(in data: Data) -> TokenEvent? {
        let content = String(decoding: data, as: UTF8.self)
        for line in content.split(separator: "\n").reversed() {
            guard line.contains("\"token_count\""),
                  let object = parseJSONObject(line),
                  object["type"] as? String == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count" else { continue }
            return TokenEvent(object: object)
        }
        return nil
    }

    private func parseJSONObject(_ line: Substring) -> [String: Any]? {
        guard let data = String(line).data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func buildWeeklySnapshot(from sessions: [SessionAccumulator], latestLimit: LimitSnapshot?) -> WeeklyUsageSnapshot {
        let now = Date()
        let window = weeklyWindow(for: latestLimit, now: now)
        let weekStart = window.start
        let weekEnd = window.end
        var totalsByDay: [String: Int] = [:]
        var total = TokenUsage.zero
        var count = 0

        for session in sessions {
            guard let event = session.latestEvent,
                  event.timestamp >= weekStart,
                  event.timestamp < weekEnd else { continue }
            total.input += event.total.input
            total.cachedInput += event.total.cachedInput
            total.output += event.total.output
            total.reasoningOutput += event.total.reasoningOutput
            total.total += event.total.total
            count += 1
            let key = Self.dayFormatter.string(from: event.timestamp)
            totalsByDay[key, default: 0] += event.total.total
        }

        let daily = (0..<7).compactMap { offset -> DailyTokenTotal? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart), date <= weekEnd else { return nil }
            let key = Self.dayFormatter.string(from: date)
            return DailyTokenTotal(day: key, totalTokens: totalsByDay[key, default: 0])
        }

        return WeeklyUsageSnapshot(
            totalTokens: total.total,
            inputTokens: total.input,
            cachedInputTokens: total.cachedInput,
            outputTokens: total.output,
            reasoningTokens: total.reasoningOutput,
            sessions: count,
            dailyTotals: daily,
            limit: latestLimit
        )
    }

    private func weeklyWindow(for latestLimit: LimitSnapshot?, now: Date) -> DateInterval {
        if let latestLimit,
           let resetsAt = latestLimit.resetsAt,
           latestLimit.windowMinutes > 0,
           resetsAt > now {
            let start = resetsAt.addingTimeInterval(TimeInterval(-latestLimit.windowMinutes * 60))
            return DateInterval(start: start, end: resetsAt)
        }

        if let interval = calendar.dateInterval(of: .weekOfYear, for: now) {
            return interval
        }

        return DateInterval(start: now.addingTimeInterval(-60 * 60 * 24 * 7), end: now)
    }

    private func idFromFileName(_ url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.components(separatedBy: "-").suffix(5).joined(separator: "-")
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

private struct SessionFileCandidate {
    var url: URL
    var modified: Date
}

private struct SessionAccumulator {
    var id: String
    var title: String
    var path: String
    var latestEvent: TokenEvent?

    var snapshot: SessionUsageSnapshot {
        SessionUsageSnapshot(
            id: id,
            title: title,
            path: path,
            updatedAt: latestEvent?.timestamp,
            total: latestEvent?.total ?? .zero,
            last: latestEvent?.last ?? .zero,
            contextWindow: latestEvent?.contextWindow ?? 0,
            primaryLimit: latestEvent?.primaryLimit,
            secondaryLimit: latestEvent?.secondaryLimit,
            planType: latestEvent?.planType ?? "Unknown"
        )
    }

    var summary: SessionSummary {
        SessionSummary(
            id: id,
            title: title,
            updatedAt: latestEvent?.timestamp,
            totalTokens: latestEvent?.total.total ?? 0
        )
    }
}

private struct TokenEvent {
    var timestamp: Date
    var total: TokenUsage
    var last: TokenUsage
    var contextWindow: Int
    var primaryLimit: LimitSnapshot?
    var secondaryLimit: LimitSnapshot?
    var planType: String

    init?(object: [String: Any]) {
        guard let timestampString = object["timestamp"] as? String,
              let timestamp = ISO8601DateFormatter.codex.date(from: timestampString) ?? ISO8601DateFormatter().date(from: timestampString),
              let payload = object["payload"] as? [String: Any],
              let info = payload["info"] as? [String: Any] else { return nil }

        self.timestamp = timestamp
        self.total = TokenUsage(dictionary: info["total_token_usage"] as? [String: Any])
        self.last = TokenUsage(dictionary: info["last_token_usage"] as? [String: Any])
        self.contextWindow = info["model_context_window"] as? Int ?? 0

        let rateLimits = payload["rate_limits"] as? [String: Any]
        self.primaryLimit = LimitSnapshot(dictionary: rateLimits?["primary"] as? [String: Any])
        self.secondaryLimit = LimitSnapshot(dictionary: rateLimits?["secondary"] as? [String: Any])
        self.planType = rateLimits?["plan_type"] as? String ?? "Unknown"
    }
}

private extension TokenUsage {
    init(dictionary: [String: Any]?) {
        self.input = dictionary?["input_tokens"] as? Int ?? 0
        self.cachedInput = dictionary?["cached_input_tokens"] as? Int ?? 0
        self.output = dictionary?["output_tokens"] as? Int ?? 0
        self.reasoningOutput = dictionary?["reasoning_output_tokens"] as? Int ?? 0
        self.total = dictionary?["total_tokens"] as? Int ?? input + output
    }
}

private extension LimitSnapshot {
    init?(dictionary: [String: Any]?) {
        guard let dictionary else { return nil }
        self.usedPercent = dictionary["used_percent"] as? Double ?? Double(dictionary["used_percent"] as? Int ?? 0)
        self.windowMinutes = dictionary["window_minutes"] as? Int ?? 0
        if let reset = dictionary["resets_at"] as? TimeInterval {
            self.resetsAt = Date(timeIntervalSince1970: reset)
        } else if let reset = dictionary["resets_at"] as? Int {
            self.resetsAt = Date(timeIntervalSince1970: TimeInterval(reset))
        } else {
            self.resetsAt = nil
        }
    }
}
