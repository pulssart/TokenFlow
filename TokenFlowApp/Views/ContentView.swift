import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TokenUsageStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let snapshot = store.snapshot

        VStack(spacing: 12) {
            HStack(spacing: 14) {
                UsageCard(
                    title: "Session",
                    value: DisplayFormatters.tokens(snapshot.currentSession.total.total),
                    caption: "tokens tracked",
                    symbol: "terminal",
                    accent: .teal,
                    progress: sessionUsageProgress(snapshot.currentSession)
                )

                UsageCard(
                    title: "Week",
                    value: snapshot.weekly.limit.map { DisplayFormatters.percent($0.usedPercent) } ?? DisplayFormatters.tokens(snapshot.weekly.totalTokens),
                    caption: snapshot.weekly.limit == nil ? "estimated tokens" : "quota used",
                    symbol: "calendar",
                    accent: .indigo,
                    progress: boundedProgress(snapshot.weekly.limit?.usedPercent ?? 0)
                )
            }
            .frame(height: AppLayout.summaryHeight)

            HStack(alignment: .top, spacing: 14) {
                SessionDetailCard(session: snapshot.currentSession)
                    .frame(maxWidth: .infinity)
                WeeklyCard(weekly: snapshot.weekly)
                    .frame(width: 286)
            }
            .frame(height: AppLayout.detailHeight)

            RecentSessionsCard(sessions: snapshot.recentSessions)
                .frame(height: AppLayout.recentHeight)
        }
        .padding(20)
        .frame(width: AppLayout.windowWidth, height: AppLayout.windowHeight, alignment: .top)
        .background(WindowBackground())
        .containerBackground(Color.tokenFlowWindowBackground, for: .window)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: store.isRefreshing ? "arrow.triangle.2.circlepath.circle" : "arrow.clockwise")
                }
                .help("Refresh")

                Button {
                    openWindow(id: "settings")
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .help("Settings")
            }
        }
        .overlay(alignment: .bottom) {
            if let message = store.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 10)
            }
        }
        .clipped()
    }

    private func contextProgress(_ session: SessionUsageSnapshot) -> Double {
        guard session.contextWindow > 0 else { return 0 }
        return min(Double(session.total.total) / Double(session.contextWindow), 1)
    }

    private func sessionUsageProgress(_ session: SessionUsageSnapshot) -> Double {
        if let limit = session.primaryLimit {
            return boundedProgress(limit.usedPercent)
        }
        return contextProgress(session)
    }

    private func boundedProgress(_ percent: Double) -> Double {
        min(max(percent / 100, 0), 1)
    }
}

private struct UsageCard: View {
    var title: String
    var value: String
    var caption: String
    var symbol: String
    var accent: Color
    var progress: Double

    var body: some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(title, systemImage: symbol)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(value)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                AppCircularProgress(progress: progress, tint: accent) {
                    Text("\(Int((progress * 100).rounded()))")
                        .font(.caption.weight(.semibold))
                }
                .frame(width: 76, height: 76)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct SessionDetailCard: View {
    var session: SessionUsageSnapshot

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session Codex")
                            .font(.headline)
                        Text("Last update \(DisplayFormatters.date(session.updatedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    LimitBadge(limit: session.primaryLimit)
                }

                TokenBar(
                    label: "Input",
                    value: session.total.input,
                    total: session.total.total,
                    tint: .teal,
                    help: "Input tokens are the tokens sent to the model, including your messages, tool context, files, and instructions."
                )
                TokenBar(
                    label: "Cache",
                    value: session.total.cachedInput,
                    total: session.total.total,
                    tint: .mint,
                    help: "Cache tokens are input tokens reused from a previous request instead of processed as fresh context."
                )
                TokenBar(
                    label: "Output",
                    value: session.total.output,
                    total: session.total.total,
                    tint: .orange,
                    help: "Output tokens are the tokens written back by the model in its visible response."
                )
                TokenBar(
                    label: "Reasoning",
                    value: session.total.reasoningOutput,
                    total: session.total.total,
                    tint: .purple,
                    help: "Reasoning tokens are internal thinking tokens used by reasoning models before they produce the visible response."
                )

                Divider()

                HStack {
                    Metric(label: "Last turn", value: DisplayFormatters.tokens(session.last.total))
                    Metric(label: "Window", value: DisplayFormatters.tokens(session.contextWindow))
                    Metric(label: "Total", value: DisplayFormatters.tokens(session.total.total))
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct WeeklyCard: View {
    var weekly: WeeklyUsageSnapshot

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Week")
                            .font(.headline)
                        Text("\(weekly.sessions) sessions read")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    LimitBadge(limit: weekly.limit)
                }

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(DisplayFormatters.tokens(weekly.totalTokens))
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("tokens")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                DailyBars(days: weekly.dailyTotals)

                HStack {
                    Metric(label: "Input", value: DisplayFormatters.tokens(weekly.inputTokens))
                    Metric(label: "Output", value: DisplayFormatters.tokens(weekly.outputTokens))
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct RecentSessionsCard: View {
    var sessions: [SessionSummary]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent sessions")
                        .font(.headline)
                    Spacer()
                    Text("\(sessions.count)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }

                ForEach(sessions.prefix(4)) { session in
                    HStack(spacing: 10) {
                        Image(systemName: "message.badge.waveform")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        Text(session.title)
                            .lineLimit(1)
                        Spacer()
                        Text(DisplayFormatters.tokens(session.totalTokens))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(DisplayFormatters.date(session.updatedAt))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .font(.callout)
                    .frame(height: 18)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct TokenBar: View {
    var label: String
    var value: Int
    var total: Int
    var tint: Color
    var help: String

    var body: some View {
        let progress = total > 0 ? Double(value) / Double(total) : 0

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(DisplayFormatters.tokens(value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.07))

                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 14)
        }
        .help(help)
    }
}

private struct DailyBars: View {
    var days: [DailyTokenTotal]

    var body: some View {
        let maxValue = max(days.map(\.totalTokens).max() ?? 1, 1)

        HStack(alignment: .bottom, spacing: 9) {
            ForEach(days) { day in
                VStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.teal, .indigo], startPoint: .bottom, endPoint: .top))
                        .frame(width: 18, height: max(8, CGFloat(day.totalTokens) / CGFloat(maxValue) * 68))
                    Text(day.day)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 88)
    }
}

private struct Metric: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LimitBadge: View {
    var limit: LimitSnapshot?

    var body: some View {
        if let limit {
            VStack(alignment: .trailing, spacing: 2) {
                Text(DisplayFormatters.percent(limit.usedPercent))
                    .font(.callout.weight(.semibold).monospacedDigit())
                Text("resets \(DisplayFormatters.absoluteDate(limit.resetsAt))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("no quota")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AppCircularProgress<Content: View>: View {
    var progress: Double
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(size * 0.08, 6)
            let clamped = min(max(progress, 0), 1)

            ZStack {
                Circle()
                    .strokeBorder(tint.opacity(0.18), lineWidth: lineWidth)

                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: clamped)
                    .stroke(
                        tint.gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                content
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.tokenFlowCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .clipped()
    }
}

private struct WindowBackground: View {
    var body: some View {
        Color.tokenFlowWindowBackground
        .ignoresSafeArea()
    }
}

extension Color {
    static let tokenFlowWindowBackground = Color(nsColor: .tokenFlowWindowBackground)
    static let tokenFlowCard = Color(nsColor: .textBackgroundColor)
}

private extension NSColor {
    static let tokenFlowWindowBackground = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(calibratedWhite: 0.08, alpha: 1)
            : NSColor(calibratedRed: 0.965, green: 0.965, blue: 0.955, alpha: 1)
    }
}

#Preview {
    ContentView()
        .environmentObject(TokenUsageStore())
}
