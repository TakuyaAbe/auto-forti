import Foundation

@MainActor
final class ConfigManager {
    static let shared = ConfigManager()

    private let defaults = UserDefaults.standard
    private let portKey = "vpn.port"
    private let autoConnectKey = "vpn.autoConnect"
    private let hasLaunchedKey = "app.hasLaunched"
    private let vpnTypeKey = "vpn.type"

    private init() {}

    var port: Int {
        get {
            let val = defaults.integer(forKey: portKey)
            return val > 0 ? val : 443
        }
        set { defaults.set(newValue, forKey: portKey) }
    }

    var autoConnect: Bool {
        get { defaults.bool(forKey: autoConnectKey) }
        set { defaults.set(newValue, forKey: autoConnectKey) }
    }

    var hasLaunched: Bool {
        get { defaults.bool(forKey: hasLaunchedKey) }
        set { defaults.set(newValue, forKey: hasLaunchedKey) }
    }

    var vpnType: VPNType {
        get {
            if let raw = defaults.string(forKey: vpnTypeKey),
               let type = VPNType(rawValue: raw) {
                return type
            }
            return .ssl
        }
        set { defaults.set(newValue.rawValue, forKey: vpnTypeKey) }
    }
}
