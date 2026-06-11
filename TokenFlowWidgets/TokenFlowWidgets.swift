import SwiftUI
import WidgetKit

@main
struct TokenFlowWidgets: WidgetBundle {
    var body: some Widget {
        SessionTokenWidget()
        WeeklyTokenWidget()
    }
}

struct TokenFlowEntry: TimelineEntry {
    let date: Date
    let snapshot: TokenFlowSnapshot
}

struct TokenFlowProvider: TimelineProvider {
    func placeholder(in context: Context) -> TokenFlowEntry {
        TokenFlowEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (TokenFlowEntry) -> Void) {
        completion(TokenFlowEntry(date: .now, snapshot: SharedSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TokenFlowEntry>) -> Void) {
        let entry = TokenFlowEntry(date: .now, snapshot: SharedSnapshotStore.read())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SessionTokenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokenFlowSession", provider: TokenFlowProvider()) { entry in
            SessionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("TokenFlow Session")
        .description("Tokens for the active Codex session.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct WeeklyTokenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokenFlowWeekly", provider: TokenFlowProvider()) { entry in
            WeeklyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("TokenFlow Week")
        .description("Codex quota and tokens for the week.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct SessionWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: TokenFlowEntry

    var body: some View {
        let session = entry.snapshot.currentSession
        let progress = sessionUsageProgress(session)

        if family == .systemSmall {
            SessionCircularWidget(session: session, progress: progress)
        } else {
            SessionMediumWidget(session: session, progress: progress)
        }
    }
}

private struct SessionCircularWidget: View {
    var session: SessionUsageSnapshot
    var progress: Double

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                LargeCircularProgress(progress: progress, tint: .teal)

                VStack(spacing: 0) {
                    Text("\(Int((progress * 100).rounded()))")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14)
    }
}

private struct LargeCircularProgress: View {
    var progress: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(size * 0.075, 8)
            let clamped = min(max(progress, 0), 1)

            ZStack {
                Circle()
                    .strokeBorder(.primary.opacity(0.08), lineWidth: lineWidth)

                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: clamped)
                    .stroke(
                        tint.gradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) %")
    }
}

private struct SessionMediumWidget: View {
    var session: SessionUsageSnapshot
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(.teal)
                Text("Session")
                    .font(.headline)
                Spacer()
            }

            Text(widgetTokens(session.total.total))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)

            ProgressView(value: progress)
                .tint(.teal)

            Text(session.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct WeeklyWidgetView: View {
    var entry: TokenFlowEntry

    var body: some View {
        let weekly = entry.snapshot.weekly

        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.indigo)
                Text("Week")
                    .font(.headline)
                Spacer()
                if let limit = weekly.limit {
                    Text("\(Int(limit.usedPercent.rounded())) %")
                        .font(.caption.weight(.semibold))
                }
            }

            Text(widgetTokens(weekly.totalTokens))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)

            HStack(alignment: .bottom, spacing: 4) {
                let maxValue = max(weekly.dailyTotals.map(\.totalTokens).max() ?? 1, 1)
                ForEach(weekly.dailyTotals) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.indigo.gradient)
                        .frame(height: max(6, CGFloat(day.totalTokens) / CGFloat(maxValue) * 46))
                }
            }
            .frame(maxHeight: 50)

            Text("\(weekly.sessions) sessions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(9)
    }
}

private func widgetTokens(_ value: Int) -> String {
    if value >= 1_000_000 {
        return String(format: "%.1f M", Double(value) / 1_000_000)
    }
    if value >= 1_000 {
        return String(format: "%.0f k", Double(value) / 1_000)
    }
    return "\(value)"
}

private func sessionUsageProgress(_ session: SessionUsageSnapshot) -> Double {
    if let limit = session.primaryLimit {
        return boundedProgress(limit.usedPercent)
    }
    guard session.contextWindow > 0 else { return 0 }
    return min(Double(session.total.total) / Double(session.contextWindow), 1)
}

private func boundedProgress(_ percent: Double) -> Double {
    min(max(percent / 100, 0), 1)
}
