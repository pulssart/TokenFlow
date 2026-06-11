import AppKit
import SwiftUI

@main
struct TokenFlowApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = TokenUsageStore()
    @AppStorage(AppPreferenceKeys.showMenuBarExtra) private var showMenuBarExtra = true
    @AppStorage(AppPreferenceKeys.enableWeeklyCodexAnalysis) private var enableWeeklyCodexAnalysis = false
    @AppStorage(AppPreferenceKeys.onboardingCompleted) private var onboardingCompleted = false

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCompleted {
                    ContentView()
                } else {
                    OnboardingView(auth: store.snapshot.auth) {
                        await store.refresh()
                    }
                }
            }
                .environmentObject(store)
                .frame(width: AppLayout.windowWidth, height: mainWindowHeight)
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
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await store.refresh() }
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
    static let windowHeight: CGFloat = 794
    static let summaryHeight: CGFloat = 110
    static let detailHeight: CGFloat = 300
    static let recentHeight: CGFloat = 160
    static let analysisHeight: CGFloat = 148
    static let settingsWidth: CGFloat = 440
    static let settingsHeight: CGFloat = 466

    static func windowHeight(showWeeklyAnalysis: Bool) -> CGFloat {
        showWeeklyAnalysis ? windowHeight : windowHeight - analysisHeight - 12
    }
}

private extension TokenFlowApp {
    var mainWindowHeight: CGFloat {
        onboardingCompleted ? AppLayout.windowHeight(showWeeklyAnalysis: enableWeeklyCodexAnalysis) : AppLayout.windowHeight
    }
}

extension TokenFlowSnapshot {
    var sessionRemainingPercent: Double {
        max(0, 100 - currentSession.usedPercent)
    }

    var weekRemainingPercent: Double {
        if let limit = weekly.activeLimit {
            return max(0, 100 - limit.usedPercent)
        }
        return weekly.totalTokens > 0 ? 100 : 100
    }
}
