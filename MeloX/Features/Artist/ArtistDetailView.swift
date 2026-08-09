import SwiftUI

struct ArtistDetailView: View {
    let id: Int

    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(GatewayProviderStore.self) private var gateway

    @State private var artist: Artist?
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    var body: some View {
        Group {
            switch phase {
            case .loading where artist == nil:
                ProgressView("正在载入歌手")
            case .failed(let message) where artist == nil:
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            default:
                if let artist {
                    content(artist)
                }
            }
        }
        .navigationTitle(artist?.name ?? "歌手")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reloadToken) {
            guard artist == nil else { return }
            await load()
        }
    }

    private func content(_ artist: Artist) -> some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ArtworkImage(url: artist.artworkURL, cornerRadius: 1_000)
                        .frame(width: 150, height: 150)
                    Text(artist.name)
                        .font(.title.bold())
                    if !artist.aliases.isEmpty {
                        Text(artist.aliases.joined(separator: " / "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await player.playAll(songs, sourceID: artist.id) }
                    } label: {
                        Text("播放热门歌曲")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(songs.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("热门歌曲") {
                ForEach(Array(displayedSongs.enumerated()), id: \.element.id) { index, song in
                    Button {
                        Task {
                            await player.play(song, in: songs, sourceID: artist.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            TrackRowView(song: song, index: index)
                            if let reference = song.gatewayReference {
                                Image(systemName: reference.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel(reference.platform)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        if song.gatewayReference == nil {
                            Button {
                                library.toggle(song: song)
                            } label: {
                                Label("收藏", systemImage: library.contains(song: song) ? "heart.slash" : "heart")
                            }
                            .tint(.pink)
                        }
                    }
                }
            }

            Section("专辑") {
                ForEach(albums) { album in
                    NavigationLink(value: MusicRoute.album(album)) {
                        HStack(spacing: 12) {
                            ArtworkImage(url: album.artworkURL, cornerRadius: 7)
                                .frame(width: 54, height: 54)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(album.name)
                                    .lineLimit(1)
                                Text(album.type ?? "专辑")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .musicMatchedTransitionSource(for: MusicRoute.album(album))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func load() async {
        phase = .loading
        do {
            let result = try await api.artist(id: id)
            artist = result.0
            albums = result.2
            songs = await mergedGatewaySongs(
                into: result.1,
                artist: result.0
            )
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private var displayedSongs: [Song] {
        Array(songs.filter { $0.gatewayReference == nil }.prefix(20))
            + songs.filter { $0.gatewayReference != nil }
    }

    private func mergedGatewaySongs(
        into neteaseSongs: [Song],
        artist: Artist
    ) async -> [Song] {
        do {
            let catalog = try await gateway.searchCatalog(
                query: artist.name,
                limit: 100,
                filter: GatewayCatalogFilter(
                    providerID: nil,
                    platform: nil,
                    artist: artist.name,
                    album: nil
                )
            )
            var seen = Set<String>()
            return (neteaseSongs + (catalog?.tracks.map(\.song) ?? [])).filter {
                seen.insert(Self.songKey($0)).inserted
            }
        } catch {
            return neteaseSongs
        }
    }

    private static func songKey(_ song: Song) -> String {
        let artists = song.artists
            .map { normalized($0.name) }
            .sorted()
            .joined(separator: ",")
        return "\(normalized(song.name))|\(artists)"
    }

    private static func normalized(_ value: String) -> String {
        (value.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? value)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
