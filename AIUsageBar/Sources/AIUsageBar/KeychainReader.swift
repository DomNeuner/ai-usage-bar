import Foundation

struct Credentials {
    let accessToken: String
    let expiresAt: Date?
}

enum KeychainReader {
    static let service = "Claude Code-credentials"

    /// Returns nil if the item is missing or unparseable.
    ///
    /// Reads via /usr/bin/security rather than SecItemCopyMatching. Claude Code
    /// rewrites this item with the `security` CLI whenever it rotates the token,
    /// which resets the item's ACL to trust only /usr/bin/security. Reading it
    /// directly would re-prompt for the login password after every rotation,
    /// no matter how often "Always Allow" is clicked.
    static func read() -> Credentials? {
        guard let data = readPassword(),
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

    private static func readPassword() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", service, "-w"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else { return nil }
        return data
    }
}
