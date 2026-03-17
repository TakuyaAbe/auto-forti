import AppKit
import Foundation
import Network
import SystemConfiguration
import Security

enum VPNType: String, Sendable {
    case ssl = "ssl"
    case ipsec = "ipsec"
}

enum VPNState: Sendable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error(String)

    var displayName: String {
        switch self {
        case .disconnected: L10n.disconnected
        case .connecting: L10n.connecting
        case .connected: L10n.connected
        case .disconnecting: L10n.disconnecting
        case .error(let msg): L10n.error(msg)
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isDisconnecting: Bool {
        if case .disconnecting = self { return true }
        return false
    }

    var isConnecting: Bool {
        if case .connecting = self { return true }
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

    // SSL VPN
    private var process: Process?
    private var outputBuffer = ""
    private var tempConfigURL: URL?

    // IPSec VPN
    private let ipsecServiceName = "AutoForti IPSec"
    private var ipsecStatusTimer: Timer?

    // Common
    private var activeVPNType: VPNType = .ssl
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.auto-forti.network-monitor")

    private var openfortivpnPath: String {
        SudoersManager.shared.openfortivpnPath
    }

    private init() {
        startNetworkMonitor()
    }

    private func startNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self, self.state.isConnected else { return }
                NSLog("[AutoForti] Network path changed: \(path.status)")

                if self.activeVPNType == .ssl {
                    if let proc = self.process, proc.isRunning {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if let proc = self.process, !proc.isRunning {
                                return
                            }
                            if path.status != .satisfied {
                                NSLog("[AutoForti] Network lost while connected, terminating VPN")
                                self.process?.terminate()
                            }
                        }
                    } else {
                        self.state = .disconnected
                        self.process = nil
                    }
                } else {
                    // IPSec: macOS handles disconnect, polling will catch state change
                    if path.status != .satisfied {
                        NSLog("[AutoForti] Network lost while IPSec connected")
                    }
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Public API

    func connect() {
        switch state {
        case .disconnected, .error:
            break
        default:
            return
        }

        guard let creds = KeychainManager.shared.loadCredentials() else {
            state = .error(L10n.credentialsNotSet)
            return
        }

        activeVPNType = ConfigManager.shared.vpnType

        switch activeVPNType {
        case .ssl:
            connectSSL(creds: creds)
        case .ipsec:
            connectIPSec(creds: creds)
        }
    }

    func disconnect() {
        switch activeVPNType {
        case .ssl:
            disconnectSSL()
        case .ipsec:
            disconnectIPSec()
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
        if activeVPNType == .ssl {
            if let proc = process, proc.isRunning {
                proc.terminate()
                process = nil
            }
            cleanupTempConfig()
            let killProc = Process()
            killProc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            killProc.arguments = ["killall", "openfortivpn"]
            killProc.standardOutput = FileHandle.nullDevice
            killProc.standardError = FileHandle.nullDevice
            try? killProc.run()
        } else {
            stopIPSecStatusPolling()
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
            proc.arguments = ["--nc", "stop", ipsecServiceName]
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
        }
    }

    func checkExistingProcess() {
        // Check for existing openfortivpn process (SSL VPN)
        let sslProc = Process()
        sslProc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        sslProc.arguments = ["openfortivpn"]
        let sslPipe = Pipe()
        sslProc.standardOutput = sslPipe
        sslProc.standardError = FileHandle.nullDevice
        try? sslProc.run()
        sslProc.waitUntilExit()
        if sslProc.terminationStatus == 0 {
            activeVPNType = .ssl
            state = .connected
            return
        }

        // Check for existing IPSec VPN connection
        let status = getIPSecStatus()
        if status == "Connected" {
            activeVPNType = .ipsec
            state = .connected
            startIPSecStatusPolling()
        }
    }

    // MARK: - SSL VPN

    private func connectSSL(creds: VPNCredentials) {
        // Ensure sudoers is configured for openfortivpn
        if !SudoersManager.shared.isConfigured() {
            let alert = NSAlert()
            alert.messageText = L10n.initialSetupTitle
            alert.informativeText = L10n.initialSetupMessage
            alert.addButton(withTitle: L10n.configure)
            alert.addButton(withTitle: L10n.cancel)
            alert.alertStyle = .informational

            if alert.runModal() == .alertFirstButtonReturn {
                if !SudoersManager.shared.setupWithAdminPrompt() {
                    state = .error(L10n.setupFailedTitle)
                    return
                }
            } else {
                return
            }
        }

        let port = ConfigManager.shared.port

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
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        } catch {
            state = .error(L10n.configFileError(error.localizedDescription))
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
                NSLog("[AutoForti] openfortivpn exited with status \(proc.terminationStatus)")
                NSLog("[AutoForti] output: \(self.outputBuffer)")
                if self.state.isConnected || self.state.isDisconnecting {
                    self.state = .disconnected
                } else if case .connecting = self.state {
                    self.state = .error(L10n.connectionFailed(proc.terminationStatus))
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
            state = .error(L10n.processStartFailed(error.localizedDescription))
        }
    }

    private func disconnectSSL() {
        guard let proc = process, proc.isRunning else {
            state = .disconnected
            return
        }
        state = .disconnecting
        proc.interrupt()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if let proc = self?.process, proc.isRunning {
                proc.terminate()
            }
        }
    }

    private func cleanupTempConfig() {
        if let url = tempConfigURL {
            try? FileManager.default.removeItem(at: url)
            tempConfigURL = nil
        }
    }

    // MARK: - IPSec VPN

    private func connectIPSec(creds: VPNCredentials) {
        state = .connecting

        // Ensure VPN service exists in macOS network preferences
        if !ipsecServiceExists() {
            if !createIPSecService(server: creds.server) {
                state = .error(L10n.ipsecServiceCreateFailed)
                return
            }
            // Give macOS a moment to register the new service
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startIPSecConnection(creds: creds)
            }
            return
        }

        // Update server address if changed
        updateIPSecServiceServer(creds.server)
        startIPSecConnection(creds: creds)
    }

    private func startIPSecConnection(creds: VPNCredentials) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        var args = ["--nc", "start", ipsecServiceName,
                    "--user", creds.username,
                    "--password", creds.password]
        if let secret = creds.sharedSecret, !secret.isEmpty {
            args += ["--secret", secret]
        }
        proc.arguments = args
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
            startIPSecStatusPolling()
        } catch {
            state = .error(L10n.processStartFailed(error.localizedDescription))
        }
    }

    private func disconnectIPSec() {
        state = .disconnecting

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        proc.arguments = ["--nc", "stop", ipsecServiceName]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()

        stopIPSecStatusPolling()
        state = .disconnected
    }

    // MARK: - IPSec Status Polling

    private func startIPSecStatusPolling() {
        stopIPSecStatusPolling()
        ipsecStatusTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollIPSecStatus()
            }
        }
    }

    private func stopIPSecStatusPolling() {
        ipsecStatusTimer?.invalidate()
        ipsecStatusTimer = nil
    }

    private func pollIPSecStatus() {
        let status = getIPSecStatus()

        switch status {
        case "Connected":
            if !state.isConnected {
                state = .connected
            }
        case "Connecting":
            break
        case "Disconnecting":
            if !state.isDisconnecting {
                state = .disconnecting
            }
        default:
            if state.isConnected || state.isConnecting {
                state = .disconnected
            }
            stopIPSecStatusPolling()
        }
    }

    private func getIPSecStatus() -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        proc.arguments = ["--nc", "status", ipsecServiceName]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.components(separatedBy: .newlines).first?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    // MARK: - IPSec Service Management (SystemConfiguration)

    private func ipsecServiceExists() -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        proc.arguments = ["--nc", "list"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.contains("\"\(ipsecServiceName)\"")
    }

    private func createIPSecService(server: String) -> Bool {
        var authRef: AuthorizationRef?
        let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]
        let authStatus = AuthorizationCreate(nil, nil, flags, &authRef)
        guard authStatus == errAuthorizationSuccess, let auth = authRef else {
            NSLog("[AutoForti] Failed to create authorization: \(authStatus)")
            return false
        }
        defer { AuthorizationFree(auth, []) }

        guard let prefs = SCPreferencesCreateWithAuthorization(
            nil, "AutoForti" as CFString, nil, auth
        ) else {
            NSLog("[AutoForti] Failed to create SCPreferences")
            return false
        }

        guard SCPreferencesLock(prefs, true) else {
            NSLog("[AutoForti] Failed to lock preferences")
            return false
        }
        defer { SCPreferencesUnlock(prefs) }

        // Create IPSec interface layered on IPv4
        guard let ipsecInterface = SCNetworkInterfaceCreateWithInterface(
            kSCNetworkInterfaceIPv4,
            kSCNetworkInterfaceTypeIPSec
        ) else {
            NSLog("[AutoForti] Failed to create IPSec interface")
            return false
        }

        guard let service = SCNetworkServiceCreate(prefs, ipsecInterface) else {
            NSLog("[AutoForti] Failed to create network service")
            return false
        }

        guard SCNetworkServiceSetName(service, ipsecServiceName as CFString) else {
            NSLog("[AutoForti] Failed to set service name")
            return false
        }

        // Configure IPSec settings
        guard let serviceInterface = SCNetworkServiceGetInterface(service) else {
            NSLog("[AutoForti] Failed to get service interface")
            return false
        }

        let ipsecConfig: [String: Any] = [
            "RemoteAddress": server,
            "AuthenticationMethod": "SharedSecret",
            "LocalIdentifierType": "KeyID",
            "XAuthEnabled": 1 as Int,
        ]

        guard SCNetworkInterfaceSetConfiguration(serviceInterface, ipsecConfig as CFDictionary) else {
            NSLog("[AutoForti] Failed to configure IPSec interface")
            return false
        }

        // Add to current network set
        guard let networkSet = SCNetworkSetCopyCurrent(prefs) else {
            NSLog("[AutoForti] Failed to get current network set")
            return false
        }

        guard SCNetworkSetAddService(networkSet, service) else {
            NSLog("[AutoForti] Failed to add service to network set")
            return false
        }

        guard SCPreferencesCommitChanges(prefs) else {
            NSLog("[AutoForti] Failed to commit preferences")
            return false
        }

        guard SCPreferencesApplyChanges(prefs) else {
            NSLog("[AutoForti] Failed to apply preferences")
            return false
        }

        NSLog("[AutoForti] IPSec VPN service created successfully")
        return true
    }

    private func updateIPSecServiceServer(_ server: String) {
        guard let prefs = SCPreferencesCreate(nil, "AutoForti" as CFString, nil) else { return }
        guard let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] else { return }

        for service in services {
            guard let name = SCNetworkServiceGetName(service) as String?,
                  name == ipsecServiceName,
                  let intf = SCNetworkServiceGetInterface(service),
                  let config = SCNetworkInterfaceGetConfiguration(intf) as? [String: Any],
                  let currentServer = config["RemoteAddress"] as? String
            else { continue }

            if currentServer != server {
                NSLog("[AutoForti] Server changed, recreating IPSec service")
                removeIPSecService()
                _ = createIPSecService(server: server)
            }
            return
        }
    }

    private func removeIPSecService() {
        var authRef: AuthorizationRef?
        let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]
        let authStatus = AuthorizationCreate(nil, nil, flags, &authRef)
        guard authStatus == errAuthorizationSuccess, let auth = authRef else { return }
        defer { AuthorizationFree(auth, []) }

        guard let prefs = SCPreferencesCreateWithAuthorization(
            nil, "AutoForti" as CFString, nil, auth
        ) else { return }

        guard SCPreferencesLock(prefs, true) else { return }
        defer { SCPreferencesUnlock(prefs) }

        guard let services = SCNetworkServiceCopyAll(prefs) as? [SCNetworkService] else { return }
        for service in services {
            if let name = SCNetworkServiceGetName(service) as String?, name == ipsecServiceName {
                SCNetworkServiceRemove(service)
            }
        }
        SCPreferencesCommitChanges(prefs)
        SCPreferencesApplyChanges(prefs)
    }

    // MARK: - SSL VPN Output Handling

    private func handleOutput(_ text: String) {
        outputBuffer += text
        NSLog("[AutoForti] vpn: %@", text)

        if outputBuffer.contains("Tunnel is up and running") {
            state = .connected
        } else if outputBuffer.contains("Could not authenticate to gateway") {
            state = .error(L10n.authFailed)
            process?.terminate()
        } else if outputBuffer.contains("ERROR") {
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
        alert.messageText = L10n.certDialogTitle
        alert.informativeText = L10n.certDialogMessage(hash)
        alert.addButton(withTitle: L10n.trust)
        alert.addButton(withTitle: L10n.cancel)
        alert.alertStyle = .warning

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if var creds = KeychainManager.shared.loadCredentials() {
                creds.trustedCert = hash
                _ = KeychainManager.shared.saveCredentials(creds)
            }
            state = .disconnected
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.connect()
            }
        } else {
            state = .disconnected
        }
    }
}
