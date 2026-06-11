import AppKit
import SwiftUI

@main
struct TokenFlowApp: App {
    @StateObject private var store = TokenUsageStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
                .task {
                    TokenNotificationManager.shared.requestAuthorization()
                    await store.refresh()
                }
        }
        .defaultSize(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh tokens") {
                    Task { await store.refresh() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(store)
                .frame(width: AppLayout.settingsWidth, height: AppLayout.settingsHeight)
        }
        .defaultSize(width: AppLayout.settingsWidth, height: AppLayout.settingsHeight)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarStatsView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(snapshot: store.snapshot)
        }
        .menuBarExtraStyle(.menu)
    }
}

enum AppLayout {
    static let windowWidth: CGFloat = 900
    static let windowHeight: CGFloat = 700
    static let headerHeight: CGFloat = 54
    static let summaryHeight: CGFloat = 110
    static let detailHeight: CGFloat = 300
    static let recentHeight: CGFloat = 160
    static let settingsWidth: CGFloat = 440
    static let settingsHeight: CGFloat = 260
}

private struct MenuBarLabel: View {
    var snapshot: TokenFlowSnapshot

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.horizontal.circle")
            Text("S \(remainingText(snapshot.sessionRemainingPercent)) W \(remainingText(snapshot.weekRemainingPercent))")
                .monospacedDigit()
        }
    }

    private func remainingText(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }
}

private struct MenuBarStatsView: View {
    @EnvironmentObject private var store: TokenUsageStore

    @ViewBuilder
    var body: some View {
        let snapshot = store.snapshot

        Section("Session") {
            Text("\(Int(snapshot.sessionRemainingPercent.rounded())) % remaining")
            Text("Total \(DisplayFormatters.tokens(snapshot.currentSession.total.total))")
            Text("Last turn \(DisplayFormatters.tokens(snapshot.currentSession.last.total))")
            Text("Reset \(DisplayFormatters.absoluteDate(snapshot.currentSession.primaryLimit?.resetsAt))")
        }

        Section("Week") {
            Text("\(Int(snapshot.weekRemainingPercent.rounded())) % remaining")
            Text("Total \(DisplayFormatters.tokens(snapshot.weekly.totalTokens))")
            Text("Input \(DisplayFormatters.tokens(snapshot.weekly.inputTokens))")
            Text("Output \(DisplayFormatters.tokens(snapshot.weekly.outputTokens))")
            Text("Reset \(DisplayFormatters.absoluteDate(snapshot.weekly.limit?.resetsAt))")
        }

        Divider()

        Button("Refresh") {
            Task { await store.refresh() }
        }

        Button("Show TokenFlow") {
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit TokenFlow") {
            NSApp.terminate(nil)
        }
    }
}

extension TokenFlowSnapshot {
    var sessionRemainingPercent: Double {
        if let limit = currentSession.primaryLimit {
            return max(0, 100 - limit.usedPercent)
        }
        guard currentSession.contextWindow > 0 else { return 100 }
        let used = Double(currentSession.total.total) / Double(currentSession.contextWindow) * 100
        return max(0, 100 - used)
    }

    var weekRemainingPercent: Double {
        if let limit = weekly.limit {
            return max(0, 100 - limit.usedPercent)
        }
        return weekly.totalTokens > 0 ? 100 : 100
    }
}
