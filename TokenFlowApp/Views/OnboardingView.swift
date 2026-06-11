import SwiftUI

struct OnboardingView: View {
    var auth: AuthSnapshot
    var refresh: () async -> Void

    @AppStorage(AppPreferenceKeys.showMenuBarExtra) private var showMenuBarExtra = true
    @AppStorage(AppPreferenceKeys.enableNotifications) private var enableNotifications = true
    @AppStorage(AppPreferenceKeys.onboardingCompleted) private var onboardingCompleted = false
    @State private var step = 0

    private let stepCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Welcome to TokenFlow")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("Set it up once, then keep an eye on Codex usage without digging through logs.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StepIndicator(currentStep: step, count: stepCount)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    OnboardingStepButton(index: 0, title: "Understand", symbol: "chart.line.uptrend.xyaxis", currentStep: $step)
                    OnboardingStepButton(index: 1, title: "Sign in", symbol: "key", currentStep: $step)
                    OnboardingStepButton(index: 2, title: "Preferences", symbol: "bell.badge", currentStep: $step)
                }
                .frame(width: 170)

                Divider()

                Group {
                    switch step {
                    case 0:
                        PurposeStep()
                    case 1:
                        SignInStep(auth: auth, refresh: refresh)
                    default:
                        PreferencesStep(showMenuBarExtra: $showMenuBarExtra, enableNotifications: $enableNotifications)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Spacer()

            HStack {
                Button {
                    step = max(step - 1, 0)
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(step == 0)

                Spacer()

                Button {
                    if step == stepCount - 1 {
                        if enableNotifications {
                            TokenNotificationManager.shared.requestAuthorization()
                        }
                        onboardingCompleted = true
                    } else {
                        step += 1
                    }
                } label: {
                    Label(step == stepCount - 1 ? "Start using TokenFlow" : "Continue", systemImage: step == stepCount - 1 ? "checkmark" : "chevron.right")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: AppLayout.windowWidth, height: AppLayout.windowHeight, alignment: .topLeading)
        .background(Color.tokenFlowWindowBackground)
        .containerBackground(Color.tokenFlowWindowBackground, for: .window)
    }
}

private struct PurposeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What the app does")
                .font(.title3.weight(.semibold))

            Text("TokenFlow reads local Codex usage and turns it into a simple dashboard. You see the current session, recent sessions, and weekly usage in one place.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                OnboardingFact(symbol: "terminal", title: "Session", text: "Follow the active Codex session and its reset time.")
                OnboardingFact(symbol: "clock.arrow.circlepath", title: "Recent work", text: "See which conversations used tokens today.")
                OnboardingFact(symbol: "calendar", title: "Week", text: "Track how much of the weekly quota is already used.")
            }
        }
    }
}

private struct SignInStep: View {
    var auth: AuthSnapshot
    var refresh: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in with Codex")
                .font(.title3.weight(.semibold))

            Text("TokenFlow uses your local Codex login to read usage. The login opens in Terminal because Codex handles auth there.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Label(auth.isSignedIn ? "Signed in with \(auth.mode)" : "Login required", systemImage: auth.isSignedIn ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(auth.isSignedIn ? .green : .secondary)
                Spacer()
                Button {
                    CodexAuthReader().openLogin()
                } label: {
                    Label(auth.isSignedIn ? "Open Codex login" : "Sign in with Codex", systemImage: "key")
                }
            }
            .padding(14)
            .background(Color.tokenFlowCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                Task { await refresh() }
            } label: {
                Label("Check login", systemImage: "arrow.clockwise")
            }
        }
    }
}

private struct PreferencesStep: View {
    @Binding var showMenuBarExtra: Bool
    @Binding var enableNotifications: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose what stays visible")
                .font(.title3.weight(.semibold))

            Text("Notifications warn you when usage crosses important limits. The menu bar item keeps session and week status visible while you work.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable notifications", isOn: $enableNotifications)
                Toggle("Show menu bar item", isOn: $showMenuBarExtra)
            }
            .toggleStyle(.switch)
            .padding(14)
            .background(Color.tokenFlowCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct OnboardingFact: View {
    var symbol: String
    var title: String
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct OnboardingStepButton: View {
    var index: Int
    var title: String
    var symbol: String
    @Binding var currentStep: Int

    var body: some View {
        Button {
            currentStep = index
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(currentStep == index ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StepIndicator: View {
    var currentStep: Int
    var count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel("Step \(currentStep + 1) of \(count)")
    }
}
