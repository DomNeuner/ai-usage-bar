import Foundation

enum UsageError: Error {
    case noCredentials
    case unauthorized
    case network(Error)
    case decoding(Error)
}

struct UsageService {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    func fetch() async throws -> Usage {
        // Never cache the token: Claude Code rotates it. Re-read the Keychain
        // on every attempt; retry at most once on expiry/401/403.
        for attempt in 0..<2 {
            guard let creds = KeychainReader.read() else { throw UsageError.noCredentials }
            if let exp = creds.expiresAt, exp < Date() {
                if attempt == 0 { continue }
                throw UsageError.unauthorized
            }
            do {
                return try await request(token: creds.accessToken)
            } catch UsageError.unauthorized {
                if attempt == 0 { continue }
                throw UsageError.unauthorized
            }
        }
        throw UsageError.unauthorized
    }

    private func request(token: String) async throws -> Usage {
        var req = URLRequest(url: Self.endpoint)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw UsageError.network(error)
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 || http.statusCode == 403 { throw UsageError.unauthorized }
            if !(200..<300).contains(http.statusCode) {
                throw UsageError.network(URLError(.badServerResponse))
            }
        }
        do {
            return try Usage.decode(from: data)
        } catch {
            throw UsageError.decoding(error)
        }
    }
}
