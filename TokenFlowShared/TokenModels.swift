import Foundation

struct TokenFlowSnapshot: Codable, Equatable {
    var generatedAt: Date
    var auth: AuthSnapshot
    var currentSession: SessionUsageSnapshot
    var weekly: WeeklyUsageSnapshot
    var recentSessions: [SessionSummary]

    static let empty = TokenFlowSnapshot(
        generatedAt: .now,
        auth: .missing,
        currentSession: .empty,
        weekly: .empty,
        recentSessions: []
    )
}

struct AuthSnapshot: Codable, Equatable {
    var isSignedIn: Bool
    var mode: String
    var lastRefresh: Date?

    static let missing = AuthSnapshot(isSignedIn: false, mode: "Not connected", lastRefresh: nil)
}

struct SessionUsageSnapshot: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var path: String
    var updatedAt: Date?
    var total: TokenUsage
    var last: TokenUsage
    var contextWindow: Int
    var primaryLimit: LimitSnapshot?
    var secondaryLimit: LimitSnapshot?
    var planType: String

    static let empty = SessionUsageSnapshot(
        id: "empty",
        title: "No Codex session",
        path: "",
        updatedAt: nil,
        total: .zero,
        last: .zero,
        contextWindow: 0,
        primaryLimit: nil,
        secondaryLimit: nil,
        planType: "Unknown"
    )
}

struct WeeklyUsageSnapshot: Codable, Equatable {
    var totalTokens: Int
    var inputTokens: Int
    var cachedInputTokens: Int
    var outputTokens: Int
    var reasoningTokens: Int
    var sessions: Int
    var dailyTotals: [DailyTokenTotal]
    var limit: LimitSnapshot?

    static let empty = WeeklyUsageSnapshot(
        totalTokens: 0,
        inputTokens: 0,
        cachedInputTokens: 0,
        outputTokens: 0,
        reasoningTokens: 0,
        sessions: 0,
        dailyTotals: [],
        limit: nil
    )

    init(
        totalTokens: Int,
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        reasoningTokens: Int,
        sessions: Int,
        dailyTotals: [DailyTokenTotal],
        limit: LimitSnapshot?
    ) {
        self.totalTokens = totalTokens
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.sessions = sessions
        self.dailyTotals = dailyTotals
        self.limit = limit
    }

    private enum CodingKeys: String, CodingKey {
        case totalTokens
        case inputTokens
        case cachedInputTokens
        case outputTokens
        case reasoningTokens
        case sessions
        case dailyTotals
        case limit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalTokens = try container.decode(Int.self, forKey: .totalTokens)
        inputTokens = try container.decode(Int.self, forKey: .inputTokens)
        cachedInputTokens = try container.decodeIfPresent(Int.self, forKey: .cachedInputTokens) ?? 0
        outputTokens = try container.decode(Int.self, forKey: .outputTokens)
        reasoningTokens = try container.decodeIfPresent(Int.self, forKey: .reasoningTokens) ?? 0
        sessions = try container.decode(Int.self, forKey: .sessions)
        dailyTotals = try container.decode([DailyTokenTotal].self, forKey: .dailyTotals)
        limit = try container.decodeIfPresent(LimitSnapshot.self, forKey: .limit)
    }
}

struct DailyTokenTotal: Codable, Equatable, Identifiable {
    var id: String { day }
    var day: String
    var totalTokens: Int
}

struct SessionSummary: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var updatedAt: Date?
    var totalTokens: Int
}

struct TokenUsage: Codable, Equatable {
    var input: Int
    var cachedInput: Int
    var output: Int
    var reasoningOutput: Int
    var total: Int

    static let zero = TokenUsage(input: 0, cachedInput: 0, output: 0, reasoningOutput: 0, total: 0)
}

struct LimitSnapshot: Codable, Equatable {
    var usedPercent: Double
    var windowMinutes: Int
    var resetsAt: Date?
}

extension SessionUsageSnapshot {
    var activePrimaryLimit: LimitSnapshot? {
        activePrimaryLimit(at: .now)
    }

    var activeSecondaryLimit: LimitSnapshot? {
        activeSecondaryLimit(at: .now)
    }

    var usedPercent: Double {
        usedPercent(at: .now)
    }

    var progress: Double {
        progress(at: .now)
    }

    func activePrimaryLimit(at date: Date) -> LimitSnapshot? {
        primaryLimit?.active(at: date)
    }

    func activeSecondaryLimit(at date: Date) -> LimitSnapshot? {
        secondaryLimit?.active(at: date)
    }

    func usedPercent(at date: Date) -> Double {
        if let limit = activePrimaryLimit(at: date) {
            return limit.clampedUsedPercent
        }
        guard contextWindow > 0 else { return 0 }
        return min(max(Double(total.total) / Double(contextWindow) * 100, 0), 100)
    }

    func progress(at date: Date) -> Double {
        usedPercent(at: date) / 100
    }
}

extension WeeklyUsageSnapshot {
    var activeLimit: LimitSnapshot? {
        activeLimit(at: .now)
    }

    func activeLimit(at date: Date) -> LimitSnapshot? {
        limit?.active(at: date)
    }
}

extension LimitSnapshot {
    var clampedUsedPercent: Double {
        min(max(usedPercent, 0), 100)
    }

    var progress: Double {
        clampedUsedPercent / 100
    }

    func active(at date: Date) -> LimitSnapshot? {
        guard let resetsAt else { return self }
        return resetsAt > date ? self : nil
    }
}
