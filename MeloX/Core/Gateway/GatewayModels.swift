import Foundation

nonisolated struct GatewayResolveRequest: Encodable, Sendable {
    let schemaVersion = 1
    let purpose = "playback"
    let song: GatewayResolveSong
    let requestedQuality: String

    init(song: Song, quality: MusicQuality) {
        self.song = GatewayResolveSong(song: song)
        requestedQuality = quality.apiLevel
    }
}

nonisolated struct GatewayResolveSong: Encodable, Sendable {
    let neteaseId: Int?
    let name: String
    let artists: [String]
    let album: String?
    let durationMS: Int?
    let aliases: [String]
    let external: GatewayTrackReference?
    let externalReferences: [GatewayTrackReference]

    init(song: Song) {
        neteaseId = song.gatewayReference == nil && song.id > 0
            ? song.id
            : nil
        name = song.name
        artists = song.artists.map(\.name)
        album = song.album?.name
        durationMS = song.durationMS > 0 ? song.durationMS : nil
        aliases = song.aliases
        external = song.gatewayReference
        externalReferences = song.gatewayReferences
    }
}

nonisolated struct GatewayTrackReference: Codable, Hashable, Sendable {
    let providerID: String
    let platform: String
    let trackID: String
    let lyricID: String?
    let albumID: String?
    let mainHash: String?
    let lyricURL: String?

    var systemImage: String {
        switch platform.lowercased() {
        case "bilibili": "play.rectangle.fill"
        case "joox": "music.note"
        case "kuwo", "kw": "waveform"
        case "netease", "wy": "cloud.fill"
        case "qq", "tencent", "tx": "music.note.list"
        case "kg": "headphones"
        case "mg", "migu": "antenna.radiowaves.left.and.right"
        default: "network"
        }
    }
}

nonisolated struct GatewayCatalogResponse: Decodable, Sendable {
    let schemaVersion: Int
    let tracks: [GatewayCatalogTrack]
    let artists: [GatewayCatalogArtist]
    let albums: [GatewayCatalogAlbum]
}

nonisolated struct GatewayCatalogTrack: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let artists: [String]
    let album: String?
    let durationMS: Int?
    let artworkURL: String?
    let reference: GatewayTrackReference
    let references: [GatewayTrackReference]?

    @MainActor var song: Song {
        let artistModels = artists.map { artistName in
            Artist(
                id: gatewayStableID("\(reference.providerID):\(reference.platform):artist:\(artistName)"),
                name: artistName
            )
        }
        let albumModel = album.map { albumName in
            Album(
                id: gatewayStableID("\(reference.providerID):\(reference.platform):album:\(albumName)"),
                name: albumName,
                picURL: artworkURL,
                artists: artistModels
            )
        }
        return Song(
            id: gatewayStableID(id),
            name: name,
            artists: artistModels,
            album: albumModel,
            durationMS: durationMS ?? 0,
            gatewayReference: reference,
            gatewayReferences: references ?? [reference]
        )
    }
}

nonisolated struct GatewayCatalogArtist: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let providerID: String
    let platform: String
}

nonisolated struct GatewayCatalogAlbum: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let artists: [String]
    let providerID: String
    let platform: String
    let artworkURL: String?

    var artistText: String { artists.joined(separator: " / ") }
    var artwork: URL? { artworkURL.flatMap(URL.init(string:)) }
}

nonisolated struct GatewayCatalogFilter: Hashable, Sendable {
    let providerID: String?
    let platform: String?
    let artist: String?
    let album: String?

    static let none = GatewayCatalogFilter(
        providerID: nil,
        platform: nil,
        artist: nil,
        album: nil
    )
}

private nonisolated func gatewayStableID(_ value: String) -> Int {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in value.utf8 {
        hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
    }
    return -Int((hash & 0x3fff_ffff_ffff_ffff) + 1)
}

nonisolated struct GatewayResolveResponse: Decodable, Sendable {
    let schemaVersion: Int
    let status: String
    let source: GatewayResolvedSource?
}

nonisolated struct GatewayLyricsRequest: Encodable, Sendable {
    let schemaVersion = 1
    let requestedQuality = "lossless"
    let song: GatewayResolveSong

    init(song: Song) { self.song = GatewayResolveSong(song: song) }
}

nonisolated struct GatewayLyricsResponse: Decodable, Sendable {
    let status: String
    let lyrics: GatewayLyricsPayload?
}

nonisolated struct GatewayLyricsPayload: Decodable, Sendable {
    let lrc: String?
    let translationLRC: String?
    let romanizationLRC: String?
    let yrc: String?
}

nonisolated struct GatewayResolvedSource: Decodable, Sendable {
    let providerID: String
    let url: String
    let bitrate: Int?
    let format: String?
    let quality: String?
}

nonisolated enum GatewayCapability: String, Codable, Hashable, Sendable {
    case resolve
    case lyrics
    case search

    var title: String {
        switch self {
        case .resolve: "播放音源"
        case .lyrics: "歌词"
        case .search: "目录搜索"
        }
    }
}

nonisolated enum GatewayQuality: String, Codable, Hashable, Sendable {
    case standard
    case exhigh
    case lossless
    case hires
    case jyeffect
    case sky
    case jymaster

    var title: String {
        switch self {
        case .standard: "标准"
        case .exhigh: "极高"
        case .lossless: "无损"
        case .hires: "Hi-Res"
        case .jyeffect: "高清环绕声"
        case .sky: "沉浸环绕声"
        case .jymaster: "超清母带"
        }
    }
}

nonisolated struct GatewayProvider: Codable, Equatable, Identifiable, Sendable {
    let providerID: String
    let name: String
    let providerType: String
    var enabled: Bool
    var priority: Int
    let capabilities: [GatewayCapability]
    let supportedSources: [String]
    let qualities: [GatewayQuality]
    var status: String
    var latencyMS: Int?
    var lastCheckedAt: String?
    var lastError: String?

    var id: String { providerID }
}

nonisolated struct GatewayProvidersResponse: Decodable, Sendable {
    let schemaVersion: Int
    let providers: [GatewayProvider]
}

nonisolated struct GatewayProviderCheckResponse: Decodable, Sendable {
    let providerID: String
    let status: String
    let latencyMS: Int?
    let message: String?
    let checkedAt: String
}

nonisolated enum GatewayConnectionState: Equatable, Sendable {
    case notConfigured
    case disabled
    case connecting
    case connected(latencyMS: Int)
    case failed(String)

    var title: String {
        switch self {
        case .notConfigured: "未配置"
        case .disabled: "已停用"
        case .connecting: "正在连接"
        case .connected: "已连接"
        case .failed: "连接异常"
        }
    }

    var systemImage: String {
        switch self {
        case .notConfigured: "circle.dashed"
        case .disabled: "pause.circle"
        case .connecting: "arrow.trianglehead.2.clockwise.rotate.90"
        case .connected: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
}
