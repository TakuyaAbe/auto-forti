import AppKit

@MainActor
final class SetupWindowController {
    private var window: NSWindow?
    var onSave: (@MainActor @Sendable () -> Void)?

    func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = L10n.setupTitle
        w.center()
        w.isReleasedWhenClosed = false

        let contentView = NSView(frame: w.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let keychain = KeychainManager.shared
        let config = ConfigManager.shared
        let existing = keychain.loadCredentials()

        // Helper to create a form row
        func makeRow(label: String, field: NSView) -> NSStackView {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8
            let labelView = NSTextField(labelWithString: label)
            labelView.alignment = .right
            labelView.translatesAutoresizingMaskIntoConstraints = false
            labelView.widthAnchor.constraint(equalToConstant: 130).isActive = true
            field.translatesAutoresizingMaskIntoConstraints = false
            if let tf = field as? NSTextField {
                tf.widthAnchor.constraint(equalToConstant: 220).isActive = true
            } else if let popup = field as? NSPopUpButton {
                popup.translatesAutoresizingMaskIntoConstraints = false
                popup.widthAnchor.constraint(equalToConstant: 220).isActive = true
            }
            row.addArrangedSubview(labelView)
            row.addArrangedSubview(field)
            return row
        }

        // VPN Type selector
        let typePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        typePopup.addItems(withTitles: [L10n.sslVPN, L10n.ipsecVPN])
        typePopup.selectItem(at: config.vpnType == .ipsec ? 1 : 0)
        let typeRow = makeRow(label: L10n.vpnType, field: typePopup)

        // Server
        let serverField = NSTextField(frame: .zero)
        serverField.stringValue = existing?.server ?? ""
        let serverRow = makeRow(label: L10n.server, field: serverField)

        // Port (SSL only)
        let portField = NSTextField(frame: .zero)
        portField.stringValue = String(config.port)
        let portRow = makeRow(label: L10n.port, field: portField)

        // Username
        let usernameField = NSTextField(frame: .zero)
        usernameField.stringValue = existing?.username ?? ""
        let usernameRow = makeRow(label: L10n.username, field: usernameField)

        // Password
        let passwordField = NSSecureTextField(frame: .zero)
        passwordField.stringValue = existing?.password ?? ""
        let passwordRow = makeRow(label: L10n.password, field: passwordField)

        // Trusted Cert (SSL only)
        let trustedCertField = NSTextField(frame: .zero)
        trustedCertField.stringValue = existing?.trustedCert ?? ""
        trustedCertField.placeholderString = L10n.trustedCertPlaceholder
        let trustedCertRow = makeRow(label: L10n.trustedCert, field: trustedCertField)

        // Shared Secret (IPSec only)
        let sharedSecretField = NSSecureTextField(frame: .zero)
        sharedSecretField.stringValue = existing?.sharedSecret ?? ""
        let sharedSecretRow = makeRow(label: L10n.sharedSecret, field: sharedSecretField)

        // Stack view
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        stackView.addArrangedSubview(typeRow)
        stackView.addArrangedSubview(serverRow)
        stackView.addArrangedSubview(portRow)
        stackView.addArrangedSubview(usernameRow)
        stackView.addArrangedSubview(passwordRow)
        stackView.addArrangedSubview(trustedCertRow)
        stackView.addArrangedSubview(sharedSecretRow)

        // Auto-connect checkbox
        let autoConnectCheck = NSButton(
            checkboxWithTitle: L10n.autoConnectOnLaunch, target: nil, action: nil)
        autoConnectCheck.state = config.autoConnect ? .on : .off
        stackView.addArrangedSubview(autoConnectCheck)

        // Buttons
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let saveButton = NSButton(title: L10n.save, target: nil, action: nil)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: L10n.cancel, target: nil, action: nil)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        buttonRow.addArrangedSubview(NSView()) // spacer
        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(saveButton)
        stackView.addArrangedSubview(buttonRow)

        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // Update field visibility based on VPN type
        func updateVisibility() {
            let isIPSec = typePopup.indexOfSelectedItem == 1
            portRow.isHidden = isIPSec
            trustedCertRow.isHidden = isIPSec
            sharedSecretRow.isHidden = !isIPSec
        }
        updateVisibility()

        // Type change handler
        let typeAction = ButtonAction { updateVisibility() }
        typePopup.target = typeAction
        typePopup.action = #selector(ButtonAction.doAction)

        // Save handler
        let saveAction = ButtonAction { [weak self, weak w] in
            let isIPSec = typePopup.indexOfSelectedItem == 1
            let server = serverField.stringValue.trimmingCharacters(in: .whitespaces)
            let username = usernameField.stringValue.trimmingCharacters(in: .whitespaces)
            let password = passwordField.stringValue

            if isIPSec {
                let sharedSecret = sharedSecretField.stringValue
                guard !server.isEmpty, !username.isEmpty, !password.isEmpty,
                      !sharedSecret.isEmpty else {
                    let alert = NSAlert()
                    alert.messageText = L10n.inputError
                    alert.informativeText = L10n.ipsecFieldsRequired
                    alert.alertStyle = .warning
                    alert.runModal()
                    return
                }
                let creds = VPNCredentials(
                    server: server,
                    username: username,
                    password: password,
                    sharedSecret: sharedSecret
                )
                _ = keychain.saveCredentials(creds)
                config.vpnType = .ipsec
            } else {
                guard !server.isEmpty, !username.isEmpty, !password.isEmpty else {
                    let alert = NSAlert()
                    alert.messageText = L10n.inputError
                    alert.informativeText = L10n.fieldsRequired
                    alert.alertStyle = .warning
                    alert.runModal()
                    return
                }
                let port = Int(portField.stringValue) ?? 443
                let trustedCert = trustedCertField.stringValue
                    .trimmingCharacters(in: .whitespaces)
                let creds = VPNCredentials(
                    server: server,
                    username: username,
                    password: password,
                    trustedCert: trustedCert.isEmpty ? nil : trustedCert
                )
                _ = keychain.saveCredentials(creds)
                config.port = port
                config.vpnType = .ssl
            }

            config.autoConnect = autoConnectCheck.state == .on
            w?.close()
            self?.window = nil
            self?.onSave?()
        }

        let cancelAction = ButtonAction { [weak self, weak w] in
            w?.close()
            self?.window = nil
        }

        saveButton.target = saveAction
        saveButton.action = #selector(ButtonAction.doAction)
        cancelButton.target = cancelAction
        cancelButton.action = #selector(ButtonAction.doAction)

        // Prevent deallocation
        objc_setAssociatedObject(typePopup, "action", typeAction, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(saveButton, "action", saveAction, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(cancelButton, "action", cancelAction, .OBJC_ASSOCIATION_RETAIN)

        w.contentView = contentView
        self.window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Helper class for button actions
@MainActor
final class ButtonAction: NSObject {
    private let handler: @MainActor () -> Void
    init(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }
    @objc func doAction() { handler() }
}
