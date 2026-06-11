import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: TokenUsageStore

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
        }
        .padding(20)
        .frame(width: AppLayout.settingsWidth, height: AppLayout.settingsHeight)
        .background(Color.tokenFlowWindowBackground)
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
