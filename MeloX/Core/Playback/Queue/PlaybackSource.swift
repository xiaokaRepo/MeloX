import Foundation

enum PlaybackSourceOrigin: Equatable, Sendable {
    case netease
    case gateway
    case download
}

struct PlaybackSource: Equatable, Sendable {
    let url: URL
    let bitrate: Int?
    let format: String?
    let quality: MusicQuality?
    let origin: PlaybackSourceOrigin
    let httpHeaders: [String: String]

    nonisolated init(
        url: URL,
        bitrate: Int?,
        format: String?,
        quality: MusicQuality? = nil,
        origin: PlaybackSourceOrigin = .netease,
        httpHeaders: [String: String] = [:]
    ) {
        self.url = url
        self.bitrate = bitrate
        self.format = format
        self.quality = quality
        self.origin = origin
        self.httpHeaders = httpHeaders
    }

    var preferredForwardBufferDuration: TimeInterval {
        guard !url.isFileURL else { return 0 }
        if quality?.prefersExtendedBuffering == true
            || (bitrate ?? 0) >= 1_000_000 {
            return 16
        }
        return 8
    }
}
