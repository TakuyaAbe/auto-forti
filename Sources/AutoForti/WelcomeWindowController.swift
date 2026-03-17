import AppKit

@MainActor
final class WelcomeWindowController {
    private var window: NSWindow?
    var onContinue: (@MainActor @Sendable () -> Void)?

    func showWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = L10n.welcomeTitle
        w.center()
        w.isReleasedWhenClosed = false

        let contentView = NSView(frame: w.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.edgeInsets = NSEdgeInsets(top: 30, left: 30, bottom: 30, right: 30)

        // App icon
        if let appIcon = NSApp.applicationIconImage {
            let iconView = NSImageView(image: appIcon)
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.widthAnchor.constraint(equalToConstant: 80).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 80).isActive = true
            stackView.addArrangedSubview(iconView)
        }

        // Title
        let titleLabel = NSTextField(labelWithString: "AutoForti")
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        stackView.addArrangedSubview(titleLabel)

        // Description
        let descText = """
        \(L10n.welcomeDescription)

        \(L10n.features)
        • \(L10n.featureConnect)
        • \(L10n.featureAutoConnect)
        • \(L10n.featureKeychain)

        \(L10n.welcomeNext)
        """
        let descLabel = NSTextField(wrappingLabelWithString: descText)
        descLabel.font = NSFont.systemFont(ofSize: 13)
        descLabel.alignment = .left
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.widthAnchor.constraint(equalToConstant: 400).isActive = true
        stackView.addArrangedSubview(descLabel)

        // Spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        stackView.addArrangedSubview(spacer)

        // Start button
        let startButton = NSButton(title: L10n.getStarted, target: nil, action: nil)
        startButton.bezelStyle = .rounded
        startButton.keyEquivalent = "\r"
        startButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        stackView.addArrangedSubview(startButton)

        let buttonAction = ButtonAction { [weak self, weak w] in
            w?.close()
            self?.window = nil
            self?.onContinue?()
        }
        startButton.target = buttonAction
        startButton.action = #selector(ButtonAction.doAction)
        objc_setAssociatedObject(startButton, "action", buttonAction, .OBJC_ASSOCIATION_RETAIN)

        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        w.contentView = contentView
        self.window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
