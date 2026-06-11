import Foundation
import WidgetKit

@MainActor
final class TokenUsageStore: ObservableObject {
    @Published private(set) var snapshot: TokenFlowSnapshot = .empty
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?

    private let reader = CodexUsageReader()

    func refresh() async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            let snapshot = try reader.readSnapshot()
            self.snapshot = snapshot
            SharedSnapshotStore.write(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
            TokenNotificationManager.shared.evaluate(snapshot)
        } catch {
            errorMessage = error.localizedDescription
            snapshot = SharedSnapshotStore.read()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
