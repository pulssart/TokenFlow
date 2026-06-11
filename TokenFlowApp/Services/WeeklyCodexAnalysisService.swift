import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct WeeklyCodexAnalysis: Equatable {
    var text: String
    var generatedAt: Date
}

enum WeeklyCodexAnalysisState: Equatable {
    case idle
    case loading
    case ready(WeeklyCodexAnalysis)
    case unavailable(String)
    case failed(String)
}

struct WeeklyCodexAnalysisService {
    func analyze(snapshot: TokenFlowSnapshot) async throws -> WeeklyCodexAnalysis {
        guard snapshot.weekly.totalTokens > 0 || !snapshot.recentSessions.isEmpty else {
            return WeeklyCodexAnalysis(
                text: "No Codex work was found for this week yet. Refresh after a few sessions to get a useful summary.",
                generatedAt: .now
            )
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await analyzeWithFoundationModel(snapshot: snapshot)
        }
        #endif

        throw WeeklyCodexAnalysisError.unavailable("Apple Foundation Model requires macOS Tahoe and Apple Intelligence.")
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func analyzeWithFoundationModel(snapshot: TokenFlowSnapshot) async throws -> WeeklyCodexAnalysis {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw WeeklyCodexAnalysisError.unavailable(availabilityMessage(for: reason))
        }

        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are TokenFlow's local weekly Codex analyst.
            Use only the data provided by the app.
            Do not invent project details when session titles are vague.
            Write in English because the app UI is in English.
            Keep the answer under 130 words.
            Return exactly five short lines prefixed Work:, Intensity:, Optimization:, Focus:, and Next:.
            Give practical token advice based on input, cache, output, reasoning, session count, and daily distribution.
            Focus should name the dominant kind of work inferred from recent session titles.
            Next should give one concrete action for the next Codex session.
            """
        )

        let response = try await session.respond(
            to: prompt(for: snapshot),
            options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 190)
        )

        return WeeklyCodexAnalysis(
            text: cleaned(response.content),
            generatedAt: .now
        )
    }

    @available(macOS 26.0, *)
    private func availabilityMessage(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "Apple Foundation Model is not available on this Mac."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence needs to be enabled before TokenFlow can generate this analysis."
        case .modelNotReady:
            return "Apple Foundation Model is still downloading or preparing. Try again in a few minutes."
        @unknown default:
            return "Apple Foundation Model is not available right now."
        }
    }
    #endif

    private func prompt(for snapshot: TokenFlowSnapshot) -> String {
        let weekly = snapshot.weekly
        let current = snapshot.currentSession
        let limit = weekly.limit.map {
            "Weekly quota: \(DisplayFormatters.percent($0.usedPercent)), resets \(DisplayFormatters.absoluteDate($0.resetsAt))"
        } ?? "Weekly quota: not exposed by Codex"
        let days = weekly.dailyTotals
            .map { "\($0.day): \(DisplayFormatters.tokens($0.totalTokens))" }
            .joined(separator: ", ")
        let sessions = snapshot.recentSessions
            .prefix(6)
            .map { "\($0.title), \(DisplayFormatters.tokens($0.totalTokens)), \(DisplayFormatters.date($0.updatedAt))" }
            .joined(separator: "\n")

        return """
        Week data:
        \(limit)
        Sessions read: \(weekly.sessions)
        Total tokens: \(DisplayFormatters.tokens(weekly.totalTokens))
        Input tokens: \(DisplayFormatters.tokens(weekly.inputTokens))
        Cached input tokens: \(DisplayFormatters.tokens(weekly.cachedInputTokens))
        Output tokens: \(DisplayFormatters.tokens(weekly.outputTokens))
        Reasoning tokens: \(DisplayFormatters.tokens(weekly.reasoningTokens))
        Daily totals: \(days)

        Current Codex session:
        Title: \(current.title)
        Total: \(DisplayFormatters.tokens(current.total.total))
        Last turn: \(DisplayFormatters.tokens(current.last.total))
        Context window: \(DisplayFormatters.tokens(current.contextWindow))

        Recent session titles:
        \(sessions.isEmpty ? "No recent session titles." : sessions)
        """
    }

    private func cleaned(_ value: String) -> String {
        value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum WeeklyCodexAnalysisError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            return message
        }
    }
}
