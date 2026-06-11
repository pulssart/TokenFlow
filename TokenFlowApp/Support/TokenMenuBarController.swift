import AppKit

@MainActor
final class TokenMenuBarController: NSObject {
    static let shared = TokenMenuBarController()

    private var statusItem: NSStatusItem?
    private weak var store: TokenUsageStore?
    private var latestSnapshot: TokenFlowSnapshot = SharedSnapshotStore.read()

    func setVisible(_ visible: Bool, store: TokenUsageStore) {
        self.store = store

        if visible {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            }
            update(snapshot: latestSnapshot)
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    func update(snapshot: TokenFlowSnapshot) {
        latestSnapshot = snapshot
        guard let statusItem else { return }

        statusItem.button?.title = "S \(remainingText(snapshot.sessionRemainingPercent)) W \(remainingText(snapshot.weekRemainingPercent))"
        statusItem.button?.image = NSImage(systemSymbolName: "bolt.horizontal.circle", accessibilityDescription: "TokenFlow")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.menu = makeMenu(for: snapshot)
    }

    private func makeMenu(for snapshot: TokenFlowSnapshot) -> NSMenu {
        let menu = NSMenu()

        addHeader("Session", to: menu)
        addDisabled("\(remainingText(snapshot.sessionRemainingPercent)) remaining", to: menu)
        addDisabled("Total \(DisplayFormatters.tokens(snapshot.currentSession.total.total))", to: menu)
        addDisabled("Last turn \(DisplayFormatters.tokens(snapshot.currentSession.last.total))", to: menu)
        addDisabled("Reset \(DisplayFormatters.absoluteDate(snapshot.currentSession.activePrimaryLimit?.resetsAt))", to: menu)

        menu.addItem(.separator())

        addHeader("Week", to: menu)
        addDisabled("\(remainingText(snapshot.weekRemainingPercent)) remaining", to: menu)
        addDisabled("Total \(DisplayFormatters.tokens(snapshot.weekly.totalTokens))", to: menu)
        addDisabled("Input \(DisplayFormatters.tokens(snapshot.weekly.inputTokens))", to: menu)
        addDisabled("Output \(DisplayFormatters.tokens(snapshot.weekly.outputTokens))", to: menu)
        addDisabled("Reset \(DisplayFormatters.absoluteDate(snapshot.weekly.activeLimit?.resetsAt))", to: menu)

        menu.addItem(.separator())
        menu.addItem(actionItem("Refresh", action: #selector(refresh)))
        menu.addItem(actionItem("Show TokenFlow", action: #selector(showTokenFlow)))
        menu.addItem(actionItem("Quit TokenFlow", action: #selector(quit)))

        return menu
    }

    private func addHeader(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        ]
        item.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        menu.addItem(item)
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func actionItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func remainingText(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    @objc private func refresh() {
        Task { await store?.refresh() }
    }

    @objc private func showTokenFlow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title == "TokenFlow" }?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
