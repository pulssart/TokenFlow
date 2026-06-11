import AppKit
import SwiftUI

@main
struct TokenFlowApp: App {
    @StateObject private var store = TokenUsageStore()
    @AppStorage(AppPreferenceKeys.showMenuBarExtra) private var showMenuBarExtra = true

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
                .onAppear {
                    TokenMenuBarController.shared.setVisible(showMenuBarExtra, store: store)
                    TokenMenuBarController.shared.update(snapshot: store.snapshot)
                }
                .onChange(of: showMenuBarExtra) { _, newValue in
                    TokenMenuBarController.shared.setVisible(newValue, store: store)
                }
                .onReceive(store.$snapshot) { snapshot in
                    TokenMenuBarController.shared.update(snapshot: snapshot)
                }
                .task {
                    TokenNotificationManager.shared.requestAuthorization()
                    await store.startAutomaticRefresh()
                }
        }
        .defaultSize(width: AppLayout.windowWidth, height: AppLayout.windowHeight)
        .windowResizability(.contentSize)
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
    }
}

enum AppLayout {
    static let windowWidth: CGFloat = 900
    static let windowHeight: CGFloat = 634
    static let summaryHeight: CGFloat = 110
    static let detailHeight: CGFloat = 300
    static let recentHeight: CGFloat = 160
    static let settingsWidth: CGFloat = 440
    static let settingsHeight: CGFloat = 360
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
