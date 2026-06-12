import AppKit
import SwiftUI
import WidgetKit

@main
struct TokenFlowWidgets: WidgetBundle {
    var body: some Widget {
        SessionTokenWidget()
        WeeklyTokenWidget()
        SessionResetCountdownWidget()
        WeeklyResetCountdownWidget()
        OutputReasoningWidget()
        SessionBlockWidget()
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
        let next = Calendar.current.date(byAdding: .minute, value: 1, to: .now) ?? .now.addingTimeInterval(60)
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

struct SessionResetCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokenFlowSessionResetCountdown", provider: TokenFlowProvider()) { entry in
            ResetCountdownWidgetView(
                title: "Session reset",
                symbol: "timer",
                tint: .teal,
                reset: entry.snapshot.currentSession.activePrimaryLimit(at: entry.date)?.resetsAt,
                fallback: "No active session reset",
                entryDate: entry.date
            )
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Session Reset")
        .description("Countdown to the next Codex session reset.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct WeeklyResetCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokenFlowWeeklyResetCountdown", provider: TokenFlowProvider()) { entry in
            ResetCountdownWidgetView(
                title: "Week reset",
                symbol: "calendar.badge.clock",
                tint: .indigo,
                reset: entry.snapshot.weekly.activeLimit(at: entry.date)?.resetsAt,
                fallback: "No active week reset",
                entryDate: entry.date
            )
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Week Reset")
        .description("Countdown to the next weekly quota reset.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct OutputReasoningWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokenFlowOutputReasoning", provider: TokenFlowProvider()) { entry in
            OutputReasoningWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Output and Reasoning")
        .description("Circular graphs for output and reasoning tokens.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct SessionBlockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokenFlowSessionBlock", provider: TokenFlowProvider()) { entry in
            SessionBlockWidgetView(session: entry.snapshot.currentSession, date: entry.date)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Session Block")
        .description("The TokenFlow session block as a widget.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

private struct SessionWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: TokenFlowEntry

    var body: some View {
        let session = entry.snapshot.currentSession
        let progress = sessionUsageProgress(session, at: entry.date)

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
                if let limit = weekly.activeLimit(at: entry.date) {
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

private struct ResetCountdownWidgetView: View {
    var title: String
    var symbol: String
    var tint: Color
    var reset: Date?
    var fallback: String
    var entryDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            if let reset, reset > entryDate {
                Text(timerInterval: entryDate...reset, countsDown: true)
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)

                Text("until \(widgetTime(reset))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Ready")
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(fallback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
    }
}

private struct OutputReasoningWidgetView: View {
    var snapshot: TokenFlowSnapshot

    var body: some View {
        let session = snapshot.currentSession
        let total = max(session.total.total, 1)
        let visualScale = max(session.total.output, session.total.reasoningOutput, 1)

        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(.orange)
                    Text("Output")
                        .font(.headline)
                }
                Text(widgetTokens(session.total.output))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                Text("visible answer tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TokenTypeRing(
                title: "Output",
                value: session.total.output,
                total: total,
                visualScale: visualScale,
                tint: .orange
            )

            TokenTypeRing(
                title: "Reasoning",
                value: session.total.reasoningOutput,
                total: total,
                visualScale: visualScale,
                tint: .purple
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct TokenTypeRing: View {
    var title: String
    var value: Int
    var total: Int
    var visualScale: Int
    var tint: Color

    var body: some View {
        let share = Double(value) / Double(max(total, 1)) * 100
        let rawProgress = Double(value) / Double(max(visualScale, 1))
        let progress = value > 0 ? max(min(max(rawProgress, 0), 1), 0.14) : 0

        VStack(spacing: 7) {
            AppCircularProgress(progress: progress, tint: tint) {
                VStack(spacing: 0) {
                    Text(widgetTokenSharePercent(share))
                        .font(.caption.weight(.semibold).monospacedDigit())
                    Text("of session")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 76, height: 76)

            VStack(spacing: 1) {
                Text(title)
                    .font(.caption.weight(.medium))
                Text(widgetTokens(value))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
    }
}

private struct SessionBlockWidgetView: View {
    var session: SessionUsageSnapshot
    var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Session", systemImage: "terminal")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(widgetExactTokens(session.total.total))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                        Text("tokens tracked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                if let primaryLimit = session.activePrimaryLimit(at: date) {
                    SessionWidgetLimitRing(
                        title: "Primary",
                        value: widgetPercent(primaryLimit.usedPercent),
                        progress: primaryLimit.progress,
                        tint: .teal
                    )
                }

                if let secondaryLimit = session.activeSecondaryLimit(at: date) {
                    SessionWidgetLimitRing(
                        title: "5.3 fallback",
                        value: widgetPercent(secondaryLimit.usedPercent),
                        progress: secondaryLimit.progress,
                        tint: .indigo
                    )
                }
            }
        }
        .padding(18)
    }
}

private struct SessionWidgetLimitRing: View {
    var title: String
    var value: String
    var progress: Double
    var tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            AppCircularProgress(progress: progress, tint: tint) {
                Text(value)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
            }
            .frame(width: 70, height: 70)
        }
        .frame(width: 74)
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

private struct AppCircularProgress<Content: View>: View {
    var progress: Double
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(size * 0.095, 7)
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

private struct WidgetCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.tokenFlowWidgetCard, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .clipped()
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

private func widgetExactTokens(_ value: Int) -> String {
    WidgetFormatters.exactTokens.string(from: NSNumber(value: value)) ?? "\(value)"
}

private func widgetPercent(_ value: Double) -> String {
    "\(Int(value.rounded())) %"
}

private func widgetTokenSharePercent(_ value: Double) -> String {
    if value > 0, value < 1 {
        return String(format: "%.1f%%", value)
    }
    return "\(Int(value.rounded()))%"
}

private func widgetTime(_ value: Date) -> String {
    WidgetFormatters.time.string(from: value)
}

private func sessionUsageProgress(_ session: SessionUsageSnapshot, at date: Date) -> Double {
    session.progress(at: date)
}

private enum WidgetFormatters {
    static let exactTokens: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension Color {
    static let tokenFlowWidgetWindowBackground = Color(nsColor: .tokenFlowWidgetWindowBackground)
    static let tokenFlowWidgetCard = Color(nsColor: .textBackgroundColor)
}

private extension NSColor {
    static let tokenFlowWidgetWindowBackground = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(calibratedWhite: 0.08, alpha: 1)
            : NSColor(calibratedRed: 0.965, green: 0.965, blue: 0.955, alpha: 1)
    }
}
