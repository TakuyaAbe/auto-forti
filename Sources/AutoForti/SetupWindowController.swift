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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "AutoForti 設定"
        w.center()
        w.isReleasedWhenClosed = false

        let contentView = NSView(frame: w.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let keychain = KeychainManager.shared
        let config = ConfigManager.shared

        // Labels and fields
        let labels = ["サーバー:", "ポート:", "ユーザー名:", "パスワード:", "Trusted Cert:"]
        let fields: [NSTextField] = labels.enumerated().map { index, _ in
            let field = index == 3
                ? NSSecureTextField(frame: .zero)
                : NSTextField(frame: .zero)
            field.translatesAutoresizingMaskIntoConstraints = false
            return field
        }

        // Pre-fill existing values
        let existing = keychain.loadCredentials()
        fields[0].stringValue = existing?.server ?? ""
        fields[1].stringValue = String(config.port)
        fields[2].stringValue = existing?.username ?? ""
        fields[3].stringValue = existing?.password ?? ""
        fields[4].stringValue = existing?.trustedCert ?? ""
        fields[4].placeholderString = "自動取得されます（空欄可）"

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        for (i, labelText) in labels.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8

            let label = NSTextField(labelWithString: labelText)
            label.alignment = .right
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 100).isActive = true

            row.addArrangedSubview(label)
            row.addArrangedSubview(fields[i])
            fields[i].widthAnchor.constraint(equalToConstant: 240).isActive = true

            stackView.addArrangedSubview(row)
        }

        // Auto-connect checkbox
        let autoConnectCheck = NSButton(checkboxWithTitle: "起動時に自動接続", target: nil, action: nil)
        autoConnectCheck.state = config.autoConnect ? .on : .off
        stackView.addArrangedSubview(autoConnectCheck)

        // Save button
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let saveButton = NSButton(title: "保存", target: nil, action: nil)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: "キャンセル", target: nil, action: nil)
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

        // Use closures via target-action pattern
        let saveAction = SaveAction { [weak self, weak w] in
            let server = fields[0].stringValue.trimmingCharacters(in: .whitespaces)
            let port = Int(fields[1].stringValue) ?? 443
            let username = fields[2].stringValue.trimmingCharacters(in: .whitespaces)
            let password = fields[3].stringValue
            let trustedCert = fields[4].stringValue.trimmingCharacters(in: .whitespaces)

            guard !server.isEmpty, !username.isEmpty, !password.isEmpty else {
                let alert = NSAlert()
                alert.messageText = "入力エラー"
                alert.informativeText = "サーバー、ユーザー名、パスワードは必須です。"
                alert.alertStyle = .warning
                alert.runModal()
                return
            }

            let creds = VPNCredentials(
                server: server,
                username: username,
                password: password,
                trustedCert: trustedCert.isEmpty ? nil : trustedCert
            )
            _ = keychain.saveCredentials(creds)
            config.port = port
            config.autoConnect = autoConnectCheck.state == .on

            w?.close()
            self?.window = nil
            self?.onSave?()
        }

        let cancelAction = CancelAction { [weak self, weak w] in
            w?.close()
            self?.window = nil
        }

        saveButton.target = saveAction
        saveButton.action = #selector(SaveAction.doAction)
        cancelButton.target = cancelAction
        cancelButton.action = #selector(CancelAction.doAction)

        // Prevent deallocation
        objc_setAssociatedObject(saveButton, "action", saveAction, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(cancelButton, "action", cancelAction, .OBJC_ASSOCIATION_RETAIN)

        w.contentView = contentView
        self.window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Helper classes for button actions
@MainActor
final class SaveAction: NSObject {
    private let handler: @MainActor () -> Void
    init(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }
    @objc func doAction() { handler() }
}

@MainActor
final class CancelAction: NSObject {
    private let handler: @MainActor () -> Void
    init(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }
    @objc func doAction() { handler() }
}
