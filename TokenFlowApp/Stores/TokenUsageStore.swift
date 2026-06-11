import Foundation
import WidgetKit

@MainActor
final class TokenUsageStore: ObservableObject {
    @Published private(set) var snapshot: TokenFlowSnapshot = SharedSnapshotStore.read()
    @Published private(set) var isRefreshing = false
    @Published private(set) var weeklyAnalysisState: WeeklyCodexAnalysisState = .idle
    @Published private(set) var isRefreshingWeeklyAnalysis = false
    @Published private(set) var errorMessage: String?

    private let refreshIntervalNanoseconds: UInt64 = 60 * 1_000_000_000

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            let snapshot = try await Task.detached(priority: .utility) {
                try CodexUsageReader().readSnapshot()
            }.value
            self.snapshot = snapshot
            SharedSnapshotStore.write(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            await TokenNotificationManager.shared.evaluate(snapshot)
            if case .idle = weeklyAnalysisState {
                Task { await self.refreshWeeklyAnalysis() }
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            snapshot = SharedSnapshotStore.read()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func refreshWeeklyAnalysis() async {
        guard !isRefreshingWeeklyAnalysis else { return }
        isRefreshingWeeklyAnalysis = true
        weeklyAnalysisState = .loading
        defer { isRefreshingWeeklyAnalysis = false }

        do {
            let snapshot = self.snapshot
            let analysis = try await WeeklyCodexAnalysisService().analyze(snapshot: snapshot)
            weeklyAnalysisState = .ready(analysis)
        } catch {
            let message = error.localizedDescription
            if message.contains("Apple Foundation Model") || message.contains("Apple Intelligence") {
                weeklyAnalysisState = .unavailable(message)
            } else {
                weeklyAnalysisState = .failed(message)
            }
        }
    }

    func startAutomaticRefresh() async {
        await refresh()

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: refreshIntervalNanoseconds)
            } catch {
                break
            }

            await refresh()
        }
    }
}
