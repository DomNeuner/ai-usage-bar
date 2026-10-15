import Foundation

struct CodexCredentials {
    let accessToken: String
    let accountId: String
}

enum CodexAuthReader {
    static var authURL: URL {
        let env = ProcessInfo.processInfo.environment["CODEX_HOME"]
        let home = (env?.isEmpty == false) ? URL(fileURLWithPath: env!) :
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        return home.appendingPathComponent("auth.json")
    }

    /// Returns nil if the file is missing, unparseable, or not a ChatGPT login.
    static func read() -> CodexCredentials? {
        guard let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["auth_mode"] as? String)?.lowercased() == "chatgpt",
              let tokens = json["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String, !token.isEmpty,
              let account = tokens["account_id"] as? String, !account.isEmpty
        else { return nil }
        return CodexCredentials(accessToken: token, accountId: account)
    }
}
