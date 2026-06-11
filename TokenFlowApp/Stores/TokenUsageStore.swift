import Foundation
import WidgetKit

@MainActor
final class TokenUsageStore: ObservableObject {
    @Published private(set) var snapshot: TokenFlowSnapshot = SharedSnapshotStore.read()
    @Published private(set) var isRefreshing = false
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
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            snapshot = SharedSnapshotStore.read()
            WidgetCenter.shared.reloadAllTimelines()
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
