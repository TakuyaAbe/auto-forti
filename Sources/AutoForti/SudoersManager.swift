import Foundation

@MainActor
final class SudoersManager {
    static let shared = SudoersManager()
    private let sudoersFile = "/etc/sudoers.d/openfortivpn"
    private let setupDoneKey = "sudoers.setupDone"

    /// Resolve openfortivpn path: bundled > homebrew
    var openfortivpnPath: String {
        if let bundlePath = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("openfortivpn").path,
           FileManager.default.isExecutableFile(atPath: bundlePath) {
            return bundlePath
        }
        return "/opt/homebrew/bin/openfortivpn"
    }

    private init() {}

    /// Check if sudoers allows running openfortivpn at its resolved path
    func isConfigured() -> Bool {
        if UserDefaults.standard.bool(forKey: setupDoneKey) {
            // Verify cached result still valid
            if canSudoRun(openfortivpnPath) {
                return true
            }
            // Cached but invalid (e.g. app moved), reset
            UserDefaults.standard.set(false, forKey: setupDoneKey)
        }
        return false
    }

    /// Setup sudoers using macOS admin password dialog (no terminal needed)
    /// Registers both the bundled path and homebrew path
    func setupWithAdminPrompt() -> Bool {
        let user = NSUserName()
        let bundledPath = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("openfortivpn").path
        let homebrewPath = "/opt/homebrew/bin/openfortivpn"

        // Build sudoers entries for all known paths
        var entries = [
            "\(user) ALL=(ALL) NOPASSWD: \(homebrewPath)",
            "\(user) ALL=(ALL) NOPASSWD: /usr/bin/killall openfortivpn",
        ]
        if let bp = bundledPath, bp != homebrewPath {
            entries.insert("\(user) ALL=(ALL) NOPASSWD: \(bp)", at: 1)
        }

        let content = entries.joined(separator: "\n")
        let script = """
        do shell script "echo '\(content)' > \(sudoersFile) && \
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

    // MARK: - Private

    private func canSudoRun(_ path: String) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        proc.arguments = ["-n", path, "--version"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus == 0
    }
}
