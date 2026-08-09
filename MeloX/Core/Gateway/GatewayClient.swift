import Foundation

actor GatewayClient {
    private let baseURL: URL
    private let token: String
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL, token: String, session: URLSession? = nil) {
        self.baseURL = baseURL
        self.token = token
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func providers() async throws -> [GatewayProvider] {
        let request = try request(path: "v1/providers")
        let data = try await data(for: request)
        return try decoder.decode(
            GatewayProvidersResponse.self,
            from: data
        ).providers
    }

    func setProvider(_ providerID: String, enabled: Bool) async throws {
        var request = try request(
            path: "v1/providers/\(encoded(providerID))",
            method: "PATCH"
        )
        request.httpBody = try encoder.encode(["enabled": enabled])
        _ = try await data(for: request)
    }

    func reorderProviders(_ providerIDs: [String]) async throws {
        var request = try request(
            path: "v1/providers/order",
            method: "PUT"
        )
        request.httpBody = try encoder.encode(["providerIDs": providerIDs])
        _ = try await data(for: request)
    }

    func checkProvider(_ providerID: String) async throws
        -> GatewayProviderCheckResponse {
        let request = try request(
            path: "v1/providers/\(encoded(providerID))/check",
            method: "POST"
        )
        let data = try await data(for: request)
        return try decoder.decode(
            GatewayProviderCheckResponse.self,
            from: data
        )
    }

    func resolvePlaybackSource(
        for song: Song,
        quality: MusicQuality
    ) async throws -> PlaybackSource {
        var request = try request(path: "v1/resolve", method: "POST")
        request.httpBody = try encoder.encode(
            GatewayResolveRequest(song: song, quality: quality)
        )
        let data = try await data(for: request)
        let response = try decoder.decode(
            GatewayResolveResponse.self,
            from: data
        )
        guard response.status == "matched",
              let source = response.source,
              let url = URL(string: source.url),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw GatewayClientError.invalidResponse
        }
        return PlaybackSource(
            url: url,
            bitrate: source.bitrate,
            format: source.format,
            quality: source.quality.flatMap(MusicQuality.init(apiLevel:))
        )
    }

    func searchCatalog(
        query: String,
        limit: Int = 30,
        filter: GatewayCatalogFilter = .none
    ) async throws -> GatewayCatalogResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "v1/search"),
            resolvingAgainstBaseURL: false
        )
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let providerID = filter.providerID {
            items.append(URLQueryItem(name: "providerID", value: providerID))
        }
        if let platform = filter.platform {
            items.append(URLQueryItem(name: "platform", value: platform))
        }
        if let artist = filter.artist {
            items.append(URLQueryItem(name: "artist", value: artist))
        }
        if let album = filter.album {
            items.append(URLQueryItem(name: "album", value: album))
        }
        components?.queryItems = items
        guard let url = components?.url else {
            throw GatewayClientError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await data(for: request)
        return try decoder.decode(GatewayCatalogResponse.self, from: data)
    }

    func lyrics(for song: Song) async throws -> GatewayLyricsResponse {
        var request = try request(path: "v1/lyrics", method: "POST")
        request.httpBody = try encoder.encode(GatewayLyricsRequest(song: song))
        let data = try await data(for: request)
        return try decoder.decode(GatewayLyricsResponse.self, from: data)
    }

    private func request(
        path: String,
        method: String = "GET"
    ) throws -> URLRequest {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method != "GET" {
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
        }
        return request
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw GatewayClientError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            let envelope = try? decoder.decode(GatewayErrorEnvelope.self, from: data)
            throw GatewayClientError.server(
                statusCode: response.statusCode,
                message: envelope?.resolvedMessage
            )
        }
        return data
    }

    private func encoded(_ pathComponent: String) -> String {
        pathComponent.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? pathComponent
    }
}

private nonisolated struct GatewayErrorEnvelope: Decodable, Sendable {
    nonisolated struct ErrorDetail: Decodable, Sendable {
        let message: String
    }

    let error: ErrorDetail?
    let message: String?

    var resolvedMessage: String? { error?.message ?? message }
}

nonisolated enum GatewayClientError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case server(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "请输入有效的 HTTP 或 HTTPS Gateway 地址和 Client Token。"
        case .invalidResponse:
            "Gateway 返回了无法识别的响应。"
        case let .server(statusCode, message):
            message ?? "Gateway 请求失败（HTTP \(statusCode)）"
        }
    }
}
