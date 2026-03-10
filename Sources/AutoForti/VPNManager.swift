import AppKit
import Foundation

enum VPNState: Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(String)

    var displayName: String {
        switch self {
        case .disconnected: "未接続"
        case .connecting: "接続中..."
        case .connected: "接続済み"
        case .disconnecting: "切断中..."
        case .error(let msg): "エラー: \(msg)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

@MainActor
final class VPNManager {
    static let shared = VPNManager()

    private(set) var state: VPNState = .disconnected {
        didSet {
            onStateChange?(state)
        }
    }

    var onStateChange: (@MainActor @Sendable (VPNState) -> Void)?

    private var process: Process?
    private var outputBuffer = ""
    private var tempConfigURL: URL?

    /// Resolve openfortivpn binary: bundled > homebrew
    private var openfortivpnPath: String {
        // Check inside app bundle first
        if let bundlePath = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("openfortivpn").path,
           FileManager.default.isExecutableFile(atPath: bundlePath) {
            return bundlePath
        }
        // Fallback to homebrew
        return "/opt/homebrew/bin/openfortivpn"
    }

    private init() {}

    func connect() {
        switch state {
        case .disconnected, .error:
            break
        default:
            return
        }

        guard let creds = KeychainManager.shared.loadCredentials() else {
            state = .error("認証情報が未設定です")
            return
        }

        let port = ConfigManager.shared.port

        // Write temporary config file (avoids password in process list)
        let configURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("autoforti-\(UUID().uuidString).conf")
        var configContent = """
        host = \(creds.server)
        port = \(port)
        username = \(creds.username)
        password = \(creds.password)
        """
        if let cert = creds.trustedCert, !cert.isEmpty {
            configContent += "\ntrusted-cert = \(cert)"
        }

        do {
            try configContent.write(to: configURL, atomically: true, encoding: .utf8)
            // Restrict permissions to owner only
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        } catch {
            state = .error("設定ファイル作成失敗: \(error.localizedDescription)")
            return
        }
        tempConfigURL = configURL

        state = .connecting
        outputBuffer = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        proc.arguments = [openfortivpnPath, "-c", configURL.path]

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.handleOutput(str)
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.handleOutput(str)
            }
        }

        proc.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self else { return }
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                self.cleanupTempConfig()
                if self.state.isConnected || self.state.displayName.starts(with: "切断") {
                    self.state = .disconnected
                } else if case .connecting = self.state {
                    self.state = .error("接続に失敗しました (exit \(proc.terminationStatus))")
                } else {
                    self.state = .disconnected
                }
                self.process = nil
            }
        }

        do {
            try proc.run()
            self.process = proc
        } catch {
            cleanupTempConfig()
            state = .error("プロセス起動失敗: \(error.localizedDescription)")
        }
    }

    func disconnect() {
        guard let proc = process, proc.isRunning else {
            state = .disconnected
            return
        }
        state = .disconnecting
        proc.interrupt()  // SIGINT for graceful shutdown

        // Force kill after 5 seconds if still running
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if let proc = self?.process, proc.isRunning {
                proc.terminate()
            }
        }
    }

    func toggle() {
        switch state {
        case .disconnected, .error:
            connect()
        case .connected:
            disconnect()
        default:
            break
        }
    }

    func cleanup() {
        if let proc = process, proc.isRunning {
            proc.terminate()
            process = nil
        }
        cleanupTempConfig()
        // Also kill any orphaned openfortivpn processes
        let killProc = Process()
        killProc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        killProc.arguments = ["killall", "openfortivpn"]
        killProc.standardOutput = FileHandle.nullDevice
        killProc.standardError = FileHandle.nullDevice
        try? killProc.run()
    }

    private func cleanupTempConfig() {
        if let url = tempConfigURL {
            try? FileManager.default.removeItem(at: url)
            tempConfigURL = nil
        }
    }

    func checkExistingProcess() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        proc.arguments = ["openfortivpn"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus == 0 {
            state = .connected
        }
    }

    // MARK: - Private

    private func handleOutput(_ text: String) {
        outputBuffer += text

        if outputBuffer.contains("Tunnel is up and running") {
            state = .connected
        } else if outputBuffer.contains("Could not authenticate to gateway") {
            state = .error("認証に失敗しました")
            process?.terminate()
        } else if outputBuffer.contains("ERROR") {
            // Extract trusted cert hash from error for auto-setup
            if let range = outputBuffer.range(of: "--trusted-cert ") {
                let afterFlag = outputBuffer[range.upperBound...]
                let hash = String(afterFlag.prefix(while: { !$0.isWhitespace && !$0.isNewline }))
                if !hash.isEmpty {
                    handleUntrustedCert(hash: hash)
                }
            }
        }
    }

    private func handleUntrustedCert(hash: String) {
        process?.terminate()

        let alert = NSAlert()
        alert.messageText = "サーバー証明書の確認"
        alert.informativeText = "サーバーの証明書ハッシュ:\n\(hash)\n\nこの証明書を信頼しますか？"
        alert.addButton(withTitle: "信頼する")
        alert.addButton(withTitle: "キャンセル")
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if var creds = KeychainManager.shared.loadCredentials() {
                creds.trustedCert = hash
                _ = KeychainManager.shared.saveCredentials(creds)
            }
            state = .disconnected
            // Reconnect with trusted cert
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.connect()
            }
        } else {
            state = .disconnected
        }
    }
}
