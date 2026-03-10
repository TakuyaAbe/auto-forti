import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var setupWindowController: SetupWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        // Setup main menu for keyboard shortcuts (Cmd+C/V/X/A)
        setupMainMenu()

        // Initialize controllers
        statusBarController = StatusBarController()
        setupWindowController = SetupWindowController()

        // Wire up events
        statusBarController.onToggleVPN = { @MainActor @Sendable [weak self] in
            self?.handleToggleVPN()
        }
        statusBarController.onOpenSettings = { @MainActor @Sendable [weak self] in
            self?.setupWindowController.showWindow()
        }

        setupWindowController.onSave = { @MainActor @Sendable [weak self] in
            self?.handleSettingsSaved()
        }

        // VPN state changes → status bar updates
        VPNManager.shared.onStateChange = { @MainActor @Sendable [weak self] state in
            self?.statusBarController.updateState(state)
        }

        // Check for existing openfortivpn process
        VPNManager.shared.checkExistingProcess()

        // Show setup on first launch if no credentials
        if !KeychainManager.shared.hasCredentials() {
            setupWindowController.showWindow()
        } else if ConfigManager.shared.autoConnect {
            VPNManager.shared.connect()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        VPNManager.shared.cleanup()
    }

    // MARK: - Private

    private func handleToggleVPN() {
        if !KeychainManager.shared.hasCredentials() {
            setupWindowController.showWindow()
            return
        }
        VPNManager.shared.toggle()
    }

    private func handleSettingsSaved() {
        // Credentials saved, ready to connect
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Edit menu (for Cmd+C/V/X/A in text fields)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
