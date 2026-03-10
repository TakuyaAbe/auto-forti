import Foundation

@MainActor
final class SudoersManager {
    static let shared = SudoersManager()
    private let sudoersFile = "/etc/sudoers.d/openfortivpn"
    private let openfortivpn = "/opt/homebrew/bin/openfortivpn"

    private init() {}

    /// Check if sudoers is already configured
    func isConfigured() -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        proc.arguments = ["-n", openfortivpn, "--version"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus == 0
    }

    /// Setup sudoers using macOS admin password dialog (no terminal needed)
    func setupWithAdminPrompt() -> Bool {
        let user = NSUserName()
        let script = """
        do shell script "\
        echo '\(user) ALL=(ALL) NOPASSWD: \(openfortivpn)' > \(sudoersFile) && \
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
        return proc.terminationStatus == 0
    }
}
