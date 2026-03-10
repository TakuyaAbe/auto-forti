import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var statusMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!

    var onToggleVPN: (@MainActor @Sendable () -> Void)?
    var onOpenSettings: (@MainActor @Sendable () -> Void)?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setupButton()
        setupMenu()
        updateState(.disconnected)
    }

    func updateState(_ state: VPNState) {
        // Update icon
        let symbolName = state.isConnected ? "lock.shield.fill" : "lock.shield"
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VPN")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        // Update menu items
        statusMenuItem.title = state.displayName
        switch state {
        case .disconnected, .error:
            toggleMenuItem.title = "接続"
            toggleMenuItem.isEnabled = true
        case .connected:
            toggleMenuItem.title = "切断"
            toggleMenuItem.isEnabled = true
        case .connecting, .disconnecting:
            toggleMenuItem.title = state.displayName
            toggleMenuItem.isEnabled = false
        }
    }

    // MARK: - Private

    private func setupButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "VPN")
            button.image?.size = NSSize(width: 18, height: 18)
        }
        statusItem.menu = menu
    }

    private func setupMenu() {
        statusMenuItem = NSMenuItem(title: "未接続", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        toggleMenuItem = NSMenuItem(title: "接続", action: #selector(toggleVPN), keyEquivalent: "v")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "設定...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func toggleVPN() {
        onToggleVPN?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quit() {
        VPNManager.shared.cleanup()
        NSApp.terminate(nil)
    }
}
