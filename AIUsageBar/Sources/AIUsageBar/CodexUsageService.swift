import Foundation

struct CodexUsageService {
    static let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    func fetch() async throws -> CodexUsage {
        // Codex CLI rewrites auth.json when it refreshes; re-read on every attempt
        // and retry at most once on 401/403. Read-only: never refresh or write.
        for attempt in 0..<2 {
            guard let creds = CodexAuthReader.read() else { throw UsageError.noCredentials }
            do {
                return try await request(creds)
            } catch UsageError.unauthorized {
                if attempt == 0 { continue }
                throw UsageError.unauthorized
            }
        }
        throw UsageError.unauthorized
    }

    private func request(_ creds: CodexCredentials) async throws -> CodexUsage {
        var req = URLRequest(url: Self.endpoint)
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(creds.accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
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
            return try CodexUsage.decode(from: data)
        } catch {
            throw UsageError.decoding(error)
        }
    }
}
