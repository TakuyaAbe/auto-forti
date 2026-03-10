import Foundation

@MainActor
final class SudoersManager {
    static let shared = SudoersManager()
    private let sudoersFile = "/etc/sudoers.d/openfortivpn"
    private let setupDoneKey = "sudoers.setupDone"

    /// Resolve openfortivpn path: bundled > homebrew
    private var openfortivpnPath: String {
        if let bundlePath = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("openfortivpn").path,
           FileManager.default.isExecutableFile(atPath: bundlePath) {
            return bundlePath
        }
        return "/opt/homebrew/bin/openfortivpn"
    }

    private init() {}

    /// Check if sudoers is already configured
    func isConfigured() -> Bool {
        if UserDefaults.standard.bool(forKey: setupDoneKey) {
            return true
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        proc.arguments = ["-n", "-l", openfortivpnPath]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        let ok = proc.terminationStatus == 0
        if ok {
            UserDefaults.standard.set(true, forKey: setupDoneKey)
        }
        return ok
    }

    /// Setup sudoers using macOS admin password dialog (no terminal needed)
    func setupWithAdminPrompt() -> Bool {
        let path = openfortivpnPath
        let user = NSUserName()
        let script = """
        do shell script "\
        echo '\(user) ALL=(ALL) NOPASSWD: \(path)' > \(sudoersFile) && \
        echo '\(user) ALL=(ALL) NOPASSWD: /usr/bin/killall openfortivpn' >> \(sudoersFile) && \
        chmod 0440 \(sudoersFile)" with administrator privileges
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        let ok = proc.terminationStatus == 0
        if ok {
            UserDefaults.standard.set(true, forKey: setupDoneKey)
        }
        return ok
    }
}
