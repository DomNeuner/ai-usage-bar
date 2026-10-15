import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var usage: Usage?
    @Published var error: String?
    @Published var isLoading = false
    @Published var codex: CodexUsage?
    @Published var codexError: String?
    @Published var codexConfigured = false

    /// Time of the most recent fetch attempt (success or failure).
    private(set) var lastFetch: Date?

    private let service = UsageService()
    private let codexService = CodexUsageService()
    /// Read only from deinit (nonisolated) and written on the main actor in init.
    private nonisolated(unsafe) var pollTask: Task<Void, Never>?

    private static let pollInterval: Duration = .seconds(300)
    private static let staleAfter: TimeInterval = 30

    init() {
        Notifier.start()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                // Scope the strong reference so it is not held across the sleep.
                if let vm = self { vm.refresh() } else { return }
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    deinit { pollTask?.cancel() }

    /// Refreshes only if the last attempt was more than 30 s ago (used on popover appear).
    func refreshIfStale() {
        if let last = lastFetch, Date().timeIntervalSince(last) < Self.staleAfter { return }
        refresh()
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        lastFetch = Date()
        Task {
            async let claudeResult = Self.run { try await self.service.fetch() }
            async let codexResult = Self.run { try await self.codexService.fetch() }
            let (c, x) = await (claudeResult, codexResult)
            switch c {
            case .success(let u): usage = u; error = nil
            case .failure(let e): error = Self.message(for: e)
            }
            switch x {
            case .success(let u): codex = u; codexError = nil; codexConfigured = true
            case .failure(let e):
                if case UsageError.noCredentials = e {
                    codexConfigured = false; codex = nil; codexError = nil
                } else {
                    codexConfigured = true; codexError = Self.codexMessage(for: e)
                }
            }
            if case .success = c { Notifier.process(usage: usage, codex: nil) }
            if case .success = x { Notifier.process(usage: nil, codex: codex) }
            isLoading = false
        }
    }

    private static func run<T>(_ op: @escaping () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await op()) } catch { return .failure(error) }
    }

    static func codexMessage(for error: Error) -> String {
        guard let e = error as? UsageError else { return "Unexpected error" }
        switch e {
        case .noCredentials, .unauthorized: return "Run codex to re-authenticate"
        case .network: return "Offline"
        case .decoding: return "Unexpected response from server"
        }
    }

    static func message(for error: Error) -> String {
        guard let e = error as? UsageError else { return "Unexpected error" }
        switch e {
        case .noCredentials, .unauthorized: return "Open Claude Code to re-authenticate"
        case .network: return "Offline"
        case .decoding: return "Unexpected response from server"
        }
    }
}
