import Foundation
import Observation

@MainActor
@Observable
final class LyricsStore {
    private(set) var songID: Int?
    private(set) var lyrics: [LyricLine] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private let api: NeteaseAPI

    @ObservationIgnored
    private let gateway: GatewayProviderStore

    @ObservationIgnored
    private var loadGeneration = 0

    init(api: NeteaseAPI, gateway: GatewayProviderStore) {
        self.api = api
        self.gateway = gateway
    }

    func load(for song: Song?) async {
        loadGeneration += 1
        let generation = loadGeneration
        songID = song?.id
        lyrics = []
        errorMessage = nil
        isLoading = song != nil
        guard let song else { return }

        do {
            do {
                if let response = try await gateway.lyrics(for: song),
                   response.status == "matched",
                   let payload = response.lyrics {
                    let loaded = LyricParser.parse(
                        yrc: payload.yrc ?? "",
                        lrc: payload.lrc ?? "",
                        translatedLRC: payload.translationLRC ?? "",
                        romanizedLRC: payload.romanizationLRC ?? ""
                    )
                    if !loaded.isEmpty {
                        guard generation == loadGeneration else { return }
                        lyrics = loaded
                        isLoading = false
                        return
                    }
                }
            } catch {
                if song.gatewayReference != nil { throw error }
            }
            guard song.id > 0 else {
                throw NSError(domain: "Lyrics", code: 1, userInfo: [NSLocalizedDescriptionKey: "当前歌曲暂无滚动歌词。"])
            }
            let loadedLyrics = try await api.lyrics(id: song.id)
            guard generation == loadGeneration else { return }
            lyrics = loadedLyrics
            errorMessage = loadedLyrics.isEmpty ? "当前歌曲暂无滚动歌词。" : nil
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func load(for songID: Int?) async {
        loadGeneration += 1
        let generation = loadGeneration

        self.songID = songID
        lyrics = []
        errorMessage = nil
        isLoading = songID != nil

        guard let songID else { return }

        do {
            let loadedLyrics = try await api.lyrics(id: songID)
            try Task.checkCancellation()
            guard generation == loadGeneration else { return }

            lyrics = loadedLyrics
            errorMessage = loadedLyrics.isEmpty
                ? "当前歌曲暂无滚动歌词。"
                : nil
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
