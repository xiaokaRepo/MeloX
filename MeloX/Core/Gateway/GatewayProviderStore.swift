import Foundation
import Observation

@MainActor
@Observable
final class GatewayProviderStore {
    private enum Key {
        static let enabled = "melox.gateway.enabled"
        static let baseURL = "melox.gateway.baseURL"
    }

    var isEnabled: Bool
    private(set) var baseURL: String
    private(set) var hasToken: Bool
    private(set) var providers: [GatewayProvider] = []
    private(set) var connectionState: GatewayConnectionState
    private(set) var checkingProviderIDs: Set<String> = []
    var lastErrorMessage: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keychain: GatewayKeychain

    init(defaults: UserDefaults = .standard) {
        let storedEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? false
        let storedBaseURL = defaults.string(forKey: Key.baseURL) ?? ""
        let keychain = GatewayKeychain()
        let storedHasToken = keychain.readToken()?.isEmpty == false

        self.defaults = defaults
        self.keychain = keychain
        isEnabled = storedEnabled
        baseURL = storedBaseURL
        hasToken = storedHasToken
        if !storedEnabled {
            connectionState = .disabled
        } else if storedBaseURL.isEmpty || !storedHasToken {
            connectionState = .notConfigured
        } else {
            connectionState = .connecting
        }
    }

    func configure(
        baseURL: String,
        token: String,
        enabled: Bool
    ) async {
        lastErrorMessage = nil
        let normalizedURL = baseURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalizedToken = token.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard normalizedURL.isEmpty || Self.validURL(normalizedURL) != nil else {
            present(error: GatewayClientError.invalidConfiguration)
            return
        }

        do {
            if !normalizedToken.isEmpty {
                try keychain.saveToken(normalizedToken)
                hasToken = true
            }
            self.baseURL = normalizedURL
            isEnabled = enabled
            defaults.set(normalizedURL, forKey: Key.baseURL)
            defaults.set(enabled, forKey: Key.enabled)
            await refresh()
        } catch {
            present(error: error)
        }
    }

    func refresh() async {
        lastErrorMessage = nil
        guard isEnabled else {
            connectionState = .disabled
            providers = []
            return
        }
        let started = ContinuousClock.now
        do {
            let client = try makeClient()
            connectionState = .connecting
            providers = try await client.providers()
            let duration = started.duration(to: .now)
            let latency = Int(duration.components.seconds * 1_000)
                + Int(duration.components.attoseconds / 1_000_000_000_000_000)
            connectionState = .connected(latencyMS: latency)
        } catch {
            connectionState = .failed(error.localizedDescription)
            present(error: error)
        }
    }

    func setProvider(_ providerID: String, enabled: Bool) async {
        lastErrorMessage = nil
        guard let index = providers.firstIndex(where: { $0.id == providerID })
        else { return }
        let previous = providers[index]
        providers[index].enabled = enabled
        providers[index].status = enabled ? "unknown" : "disabled"
        do {
            try await makeClient().setProvider(providerID, enabled: enabled)
        } catch {
            providers[index] = previous
            present(error: error)
        }
    }

    func reorderProviders(_ providerIDs: [String]) async {
        lastErrorMessage = nil
        let previous = providers
        let lookup = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
        providers = providerIDs.enumerated().compactMap { index, id in
            guard var provider = lookup[id] else { return nil }
            provider.priority = index
            return provider
        }
        do {
            try await makeClient().reorderProviders(providerIDs)
        } catch {
            providers = previous
            present(error: error)
        }
    }

    func checkProvider(_ providerID: String) async {
        lastErrorMessage = nil
        checkingProviderIDs.insert(providerID)
        defer { checkingProviderIDs.remove(providerID) }
        do {
            let result = try await makeClient().checkProvider(providerID)
            guard let index = providers.firstIndex(where: { $0.id == providerID })
            else { return }
            providers[index].status = result.status
            providers[index].latencyMS = result.latencyMS
            providers[index].lastCheckedAt = result.checkedAt
            providers[index].lastError = result.message
        } catch {
            present(error: error)
        }
    }

    func resolvePlaybackSource(
        for song: Song,
        quality: MusicQuality
    ) async throws -> PlaybackSource? {
        guard isEnabled,
              Self.validURL(baseURL) != nil,
              hasToken else {
            return nil
        }
        return try await makeClient().resolvePlaybackSource(
            for: song,
            quality: quality
        )
    }

    func searchCatalog(
        query: String,
        limit: Int = 30,
        filter: GatewayCatalogFilter = .none
    ) async throws -> GatewayCatalogResponse? {
        guard isEnabled,
              Self.validURL(baseURL) != nil,
              hasToken else {
            return nil
        }
        return try await makeClient().searchCatalog(
            query: query,
            limit: limit,
            filter: filter
        )
    }

    func lyrics(for song: Song) async throws -> GatewayLyricsResponse? {
        guard isEnabled, Self.validURL(baseURL) != nil, hasToken else { return nil }
        return try await makeClient().lyrics(for: song)
    }

    func dismissError() {
        lastErrorMessage = nil
    }

    private func makeClient() throws -> GatewayClient {
        guard let url = Self.validURL(baseURL),
              let token = keychain.readToken(),
              !token.isEmpty else {
            throw GatewayClientError.invalidConfiguration
        }
        return GatewayClient(baseURL: url, token: token)
    }

    private func present(error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    private static func validURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return nil }
        return url
    }
}
