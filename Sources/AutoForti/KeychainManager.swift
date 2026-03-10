import Foundation
import Security

struct VPNCredentials: Codable {
    var server: String
    var username: String
    var password: String
    var trustedCert: String?
}

@MainActor
final class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.auto-forti.vpn"
    private let account = "credentials"

    private init() {}

    func saveCredentials(_ creds: VPNCredentials) -> Bool {
        guard let data = try? JSONEncoder().encode(creds) else { return false }
        deleteCredentials()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func loadCredentials() -> VPNCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let creds = try? JSONDecoder().decode(VPNCredentials.self, from: data)
        else {
            return nil
        }
        return creds
    }

    @discardableResult
    func deleteCredentials() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    func hasCredentials() -> Bool {
        loadCredentials() != nil
    }
}
