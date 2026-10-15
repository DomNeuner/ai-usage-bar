import Foundation
import Security

struct Credentials {
    let accessToken: String
    let expiresAt: Date?
}

enum KeychainReader {
    static let service = "Claude Code-credentials"

    /// Returns nil if the item is missing or unparseable.
    static func read() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { return nil }

        var expiry: Date?
        if let ms = (oauth["expiresAt"] as? NSNumber)?.doubleValue {
            expiry = Date(timeIntervalSince1970: ms / 1000.0)
        }
        return Credentials(accessToken: token, expiresAt: expiry)
    }
}
