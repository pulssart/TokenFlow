import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TokenUsageStore
    @AppStorage(AppPreferenceKeys.showMenuBarExtra) private var showMenuBarExtra = true
    @AppStorage(AppPreferenceKeys.enableNotifications) private var enableNotifications = true

    var body: some View {
        let snapshot = store.snapshot

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("Codex connection")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }

            ConnectionSettingsCard(snapshot: snapshot.auth, plan: snapshot.currentSession.planType)
            PreferencesSettingsCard(showMenuBarExtra: $showMenuBarExtra, enableNotifications: $enableNotifications)
        }
        .padding(20)
        .frame(width: AppLayout.settingsWidth, height: AppLayout.settingsHeight)
        .background(Color.tokenFlowWindowBackground)
        .onChange(of: enableNotifications) { _, isEnabled in
            guard isEnabled else { return }
            TokenNotificationManager.shared.requestAuthorization()
            Task { await store.refresh() }
        }
    }
}

private struct ConnectionSettingsCard: View {
    var snapshot: AuthSnapshot
    var plan: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("ChatGPT connection", systemImage: snapshot.isSignedIn ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark")
                    .font(.headline)
                Spacer()
                Button {
                    CodexAuthReader().openLogin()
                } label: {
                    Label(snapshot.isSignedIn ? "Logged in" : "Login", systemImage: snapshot.isSignedIn ? "checkmark.circle" : "key")
                }
                .disabled(snapshot.isSignedIn)
            }

            HStack(spacing: 12) {
                SettingsMetric(label: "Status", value: snapshot.isSignedIn ? snapshot.mode : "Login required")
                SettingsMetric(label: "Plan", value: plan)
                SettingsMetric(label: "Refresh", value: DisplayFormatters.date(snapshot.lastRefresh))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.tokenFlowCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct PreferencesSettingsCard: View {
    @Binding var showMenuBarExtra: Bool
    @Binding var enableNotifications: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(.headline)

            Toggle("Show menu bar item", isOn: $showMenuBarExtra)
            Toggle("Enable notifications", isOn: $enableNotifications)
        }
        .toggleStyle(.switch)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.tokenFlowCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct SettingsMetric: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
