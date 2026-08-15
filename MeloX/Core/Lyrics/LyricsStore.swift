import Foundation
import Observation

@MainActor
@Observable
final class LyricsStore {
    private(set) var songID: Int?
    private(set) var lyrics: [LyricLine] = []
    private(set) var source: LyricSource?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private let service: LyricsService

    @ObservationIgnored
    private let gateway: GatewayProviderStore

    @ObservationIgnored
    private var loadGeneration = 0

    init(
        service: LyricsService,
        gateway: GatewayProviderStore
    ) {
        self.service = service
        self.gateway = gateway
    }

    func load(for song: Song?) async {
        loadGeneration += 1
        let generation = loadGeneration

        songID = song?.id
        lyrics = []
        source = nil
        errorMessage = nil
        isLoading = song != nil

        guard let song else { return }

        do {
            if let gatewayLyrics = try await gatewayLyrics(for: song) {
                guard generation == loadGeneration else { return }
                lyrics = gatewayLyrics.lines
                source = gatewayLyrics.source
                isLoading = false
                return
            }
            guard song.id > 0 else {
                throw LyricSourceError.noLyrics
            }
            let loaded = try await service.load(
                for: LyricsSongMetadata(song: song)
            ) { [weak self] update in
                guard let self, generation == self.loadGeneration else {
                    return
                }
                self.lyrics = update.lines
                self.source = update.source
                self.errorMessage = nil
                self.isLoading = false
            }
            try Task.checkCancellation()
            guard generation == loadGeneration else { return }

            lyrics = loaded.lines
            source = loaded.source
            errorMessage = loaded.lines.isEmpty
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

    func fetch(for song: Song) async throws -> [LyricLine] {
        if let gatewayLyrics = try await gatewayLyrics(for: song) {
            return gatewayLyrics.lines
        }
        guard song.id > 0 else { throw LyricSourceError.noLyrics }
        let resolved = try await service.load(
            for: LyricsSongMetadata(song: song),
            onUpdate: { _ in }
        )
        return resolved.lines
    }

    private func gatewayLyrics(
        for song: Song
    ) async throws -> ResolvedLyrics? {
        do {
            guard let response = try await gateway.lyrics(for: song),
                  response.status == "matched",
                  let payload = response.lyrics else {
                return nil
            }
            let lines = LyricParser.parse(
                yrc: payload.yrc ?? "",
                lrc: payload.lrc ?? "",
                translatedLRC: payload.translationLRC ?? "",
                romanizedLRC: payload.romanizationLRC ?? ""
            )
            guard !lines.isEmpty else { return nil }
            return ResolvedLyrics(
                source: .gateway,
                quality:
                    payload.yrc?.isEmpty == false
                        ? .neteaseVerbatim
                        : .neteaseLineSynchronized,
                lines: lines,
                isPureMusic: false
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if song.gatewayReference != nil { throw error }
            return nil
        }
    }
}
