import SwiftUI

enum MusicCollectionPresentationMode: String, CaseIterable, Identifiable {
    case list
    case posterWall

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .list:
            "list.bullet"
        case .posterWall:
            "square.grid.2x2"
        }
    }

    var title: String {
        switch self {
        case .list:
            "列表"
        case .posterWall:
            "海报墙"
        }
    }
}

struct PlaylistDetailContent: View {
    let playlist: Playlist
    let toplistSummary: Playlist?
    let palette: ArtworkDetailPalette
    let blurredBackdropImage: CGImage?
    let searchQuery: String
    let isLoading: Bool
    let failureMessage: String?
    let hasMoreTracks: Bool
    let loadedTrackOffset: Int
    let isLoadingMoreTracks: Bool
    let loadMoreTracksError: String?
    let downloadCoordinator: MusicCollectionDownloadCoordinator?
    let onRetry: () -> Void
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void

    @Environment(LibraryStore.self) private var library
    private var usesToplistLayout: Bool {
        toplistSummary != nil || playlist.isOfficialToplist
    }

    private var artworkURL: URL? {
        playlist.artworkURL ?? toplistSummary?.artworkURL
    }

    var body: some View {
        ZStack {
            MusicCollectionArtworkBackdrop(
                blurredArtworkImage: blurredBackdropImage,
                palette: palette
            )

            ScrollView {
                LazyVStack(spacing: 0) {
                    if usesToplistLayout {
                        ToplistDetailHero(
                            playlist: playlist,
                            summary: toplistSummary,
                            artworkURL: artworkURL,
                            palette: palette
                        )
                    } else {
                        StandardMusicCollectionDetailHero(
                            artworkURL: playlist.artworkURL,
                            title: playlist.name,
                            subtitle: playlist.creator?.nickname ?? "网易云音乐",
                            metadataText: standardMetadata,
                            tracks: playlist.tracks,
                            sourceID: playlist.id,
                            isSaved: library.contains(playlist: playlist),
                            onToggleSaved: {
                                library.toggle(playlist: playlist)
                            }
                        )
                    }

                    MusicCollectionTrackContent(
                        tracks: filteredTracks,
                        sourceID: playlist.id,
                        showsArtwork: usesToplistLayout,
                        loadingTitle: usesToplistLayout ? "正在载入排行榜" : "正在载入歌单",
                        isLoading: isLoading,
                        failureMessage: failureMessage,
                        hasMoreTracks: hasMoreTracks,
                        loadedTrackOffset: loadedTrackOffset,
                        isLoadingMoreTracks: isLoadingMoreTracks,
                        loadMoreTracksError: loadMoreTracksError,
                        downloadSelection: downloadCoordinator,
                        onRetry: onRetry,
                        onLoadMore: onLoadMore
                    )
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await onRefresh()
            }
            .ignoresSafeArea(
                .container,
                edges: usesToplistLayout ? .top : []
            )
        }
        .foregroundStyle(.primary)
    }

    private var standardMetadata: String {
        let count = playlist.trackCount > 0
            ? playlist.trackCount
            : playlist.tracks.count
        return "\(count) 首歌曲 · \(playlist.playCount.compactPlayCount) 次播放"
    }

    private var filteredTracks: [Song] {
        filterMusicCollectionTracks(playlist.tracks, query: searchQuery)
    }
}

private struct MusicCollectionPosterMosaicBlock: Identifiable {
    let id: Int
    let songs: [Song]
}

private struct MusicCollectionPosterMosaicTile {
    let column: CGFloat
    let row: CGFloat
    let span: CGFloat
}

struct MusicCollectionPosterWallScreen: View {
    let playlist: Playlist
    let palette: ArtworkDetailPalette
    let blurredBackdropImage: CGImage?
    let tracks: [Song]
    let isLoading: Bool
    let failureMessage: String?
    let hasMoreTracks: Bool
    let loadedTrackOffset: Int
    let isLoadingMoreTracks: Bool
    let loadMoreTracksError: String?
    let onRetry: () -> Void
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player

    var body: some View {
        ZStack {
            MusicCollectionArtworkBackdrop(
                blurredArtworkImage: blurredBackdropImage,
                palette: palette
            )

            ScrollView {
                MusicCollectionPosterWallContent(
                    tracks: tracks,
                    sourceID: playlist.id,
                    loadingTitle: "正在载入\(playlist.isOfficialToplist ? "排行榜" : "歌单")",
                    isLoading: isLoading,
                    failureMessage: failureMessage,
                    hasMoreTracks: hasMoreTracks,
                    loadedTrackOffset: loadedTrackOffset,
                    isLoadingMoreTracks: isLoadingMoreTracks,
                    loadMoreTracksError: loadMoreTracksError,
                    onRetry: onRetry,
                    onLoadMore: onLoadMore
                )
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await onRefresh()
            }
            .ignoresSafeArea()

            posterWallControls
                .frame(maxHeight: .infinity, alignment: .top)

            if player.currentSong != nil {
                PosterWallFloatingMiniPlayer(onExpand: { dismiss() })
                    .padding(.horizontal, 16)
                    .safeAreaPadding(.bottom, 8)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            accessibilityReduceMotion
                ? nil
                : .snappy(duration: 0.28, extraBounce: 0),
            value: player.currentSong?.id
        )
        .preferredColorScheme(palette.colorScheme)
        .presentationBackground(.clear)
    }

    private var posterWallControls: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭海报墙")

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: MusicCollectionPresentationMode.list.systemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回列表模式")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .safeAreaPadding(.top, 8)
    }
}

private struct PosterWallFloatingMiniPlayer: View {
    let onExpand: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player

    var body: some View {
        if let song = player.currentSong {
            HStack(spacing: 10) {
                Button(action: onExpand) {
                    HStack(spacing: 10) {
                        ArtworkImage(
                            url: song.album?.artworkURL,
                            cornerRadius: 9
                        )
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            Text(song.artistText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("当前播放：\(song.name)，\(song.artistText)")

                if player.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 38, height: 38)
                        .accessibilityLabel("正在载入")
                } else {
                    Button {
                        player.togglePlayback()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.semibold))
                            .contentTransition(
                                accessibilityReduceMotion
                                    ? .identity
                                    : .symbolEffect(.replace.downUp.wholeSymbol)
                            )
                            .frame(width: 38, height: 38)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 28))
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.white.opacity(0.20), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.24), radius: 20, y: 10)
        }
    }
}

struct MusicCollectionPosterWallContent: View {
    let tracks: [Song]
    let sourceID: Int
    let loadingTitle: String
    let isLoading: Bool
    let failureMessage: String?
    let hasMoreTracks: Bool
    let loadedTrackOffset: Int
    let isLoadingMoreTracks: Bool
    let loadMoreTracksError: String?
    let onRetry: () -> Void
    let onLoadMore: () async -> Void

    private var blocks: [MusicCollectionPosterMosaicBlock] {
        var result: [MusicCollectionPosterMosaicBlock] = []
        var startIndex = 0
        var blockIndex = 0

        while startIndex < tracks.count {
            let endIndex = min(startIndex + 10, tracks.count)
            result.append(
                MusicCollectionPosterMosaicBlock(
                    id: blockIndex,
                    songs: Array(tracks[startIndex..<endIndex])
                )
            )
            startIndex = endIndex
            blockIndex += 1
        }

        return result
    }

    var body: some View {
        if isLoading {
            ProgressView(loadingTitle)
                .tint(.primary)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 180)
        } else if let failureMessage {
            ConnectionUnavailableView(
                message: failureMessage,
                retry: onRetry
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        } else if tracks.isEmpty {
            ContentUnavailableView("暂无歌曲", systemImage: "square.grid.2x2")
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(blocks) { block in
                    MusicCollectionPosterMosaicBlockView(
                        block: block,
                        tracks: tracks,
                        sourceID: sourceID
                    )
                }

                if hasMoreTracks {
                    ZStack {
                        Color.black.opacity(0.78)

                        MusicCollectionPaginationFooter(
                            isLoading: isLoadingMoreTracks,
                            failureMessage: loadMoreTracksError,
                            loadToken: loadedTrackOffset,
                            action: onLoadMore
                        )
                    }
                    .frame(minHeight: 92)
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct MusicCollectionPosterMosaicBlockView: View {
    let block: MusicCollectionPosterMosaicBlock
    let tracks: [Song]
    let sourceID: Int

    private static let leadingLargeTemplate = [
        MusicCollectionPosterMosaicTile(column: 0, row: 0, span: 2),
        MusicCollectionPosterMosaicTile(column: 2, row: 0, span: 1),
        MusicCollectionPosterMosaicTile(column: 3, row: 0, span: 1),
        MusicCollectionPosterMosaicTile(column: 2, row: 1, span: 1),
        MusicCollectionPosterMosaicTile(column: 3, row: 1, span: 1),
        MusicCollectionPosterMosaicTile(column: 0, row: 2, span: 1),
        MusicCollectionPosterMosaicTile(column: 1, row: 2, span: 1),
        MusicCollectionPosterMosaicTile(column: 0, row: 3, span: 1),
        MusicCollectionPosterMosaicTile(column: 1, row: 3, span: 1),
        MusicCollectionPosterMosaicTile(column: 2, row: 2, span: 2),
    ]

    private static let trailingLargeTemplate = [
        MusicCollectionPosterMosaicTile(column: 0, row: 0, span: 1),
        MusicCollectionPosterMosaicTile(column: 1, row: 0, span: 1),
        MusicCollectionPosterMosaicTile(column: 0, row: 1, span: 1),
        MusicCollectionPosterMosaicTile(column: 1, row: 1, span: 1),
        MusicCollectionPosterMosaicTile(column: 2, row: 0, span: 2),
        MusicCollectionPosterMosaicTile(column: 0, row: 2, span: 2),
        MusicCollectionPosterMosaicTile(column: 2, row: 2, span: 1),
        MusicCollectionPosterMosaicTile(column: 3, row: 2, span: 1),
        MusicCollectionPosterMosaicTile(column: 2, row: 3, span: 1),
        MusicCollectionPosterMosaicTile(column: 3, row: 3, span: 1),
    ]

    private var template: [MusicCollectionPosterMosaicTile] {
        block.id.isMultiple(of: 2)
            ? Self.leadingLargeTemplate
            : Self.trailingLargeTemplate
    }

    private var occupiedRows: CGFloat {
        template
            .prefix(block.songs.count)
            .map { $0.row + $0.span }
            .max() ?? 1
    }

    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / 4

            ZStack(alignment: .topLeading) {
                ForEach(
                    Array(block.songs.enumerated()),
                    id: \.element.id
                ) { index, song in
                    let tile = template[index]

                    MusicCollectionPosterTile(
                        song: song,
                        tracks: tracks,
                        sourceID: sourceID,
                        isLarge: tile.span > 1
                    )
                    .frame(
                        width: unit * tile.span,
                        height: unit * tile.span
                    )
                    .offset(
                        x: unit * tile.column,
                        y: unit * tile.row
                    )
                }
            }
        }
        .aspectRatio(4 / occupiedRows, contentMode: .fit)
    }
}

private struct MusicCollectionPosterTile: View {
    let song: Song
    let tracks: [Song]
    let sourceID: Int
    let isLarge: Bool

    @Environment(PlayerStore.self) private var player

    private var isCurrentSong: Bool {
        player.currentSong?.id == song.id
    }

    var body: some View {
        Button(action: primaryAction) {
            ZStack {
                ArtworkImage(
                    url: song.album?.artworkURL,
                    cornerRadius: 0
                )

                if isCurrentSong {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font((isLarge ? Font.body : .caption).weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(
                            width: isLarge ? 48 : 34,
                            height: isLarge ? 48 : 34
                        )
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(song.name)，\(song.artistText)")
        .accessibilityValue(isCurrentSong ? "正在播放" : "")
    }

    private func primaryAction() {
        if isCurrentSong {
            player.togglePlayback()
        } else {
            Task {
                await player.play(song, in: tracks, sourceID: sourceID)
            }
        }
    }
}

struct MusicCollectionTrackContent: View {
    let tracks: [Song]
    let sourceID: Int
    let showsArtwork: Bool
    let loadingTitle: String
    let isLoading: Bool
    let failureMessage: String?
    var hasMoreTracks = false
    var loadedTrackOffset = 0
    var isLoadingMoreTracks = false
    var loadMoreTracksError: String?
    var downloadSelection: MusicCollectionDownloadCoordinator? = nil
    let onRetry: () -> Void
    var onLoadMore: () async -> Void = {}

    var body: some View {
        Group {
            if isLoading {
                ProgressView(loadingTitle)
                    .tint(.primary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else if let failureMessage {
                ConnectionUnavailableView(
                    message: failureMessage,
                    retry: onRetry
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                VStack(spacing: 0) {
                    PlaylistTrackList(
                        tracks: tracks,
                        sourceID: sourceID,
                        showsArtwork: showsArtwork,
                        downloadSelection: downloadSelection
                    )

                    if hasMoreTracks {
                        MusicCollectionPaginationFooter(
                            isLoading: isLoadingMoreTracks,
                            failureMessage: loadMoreTracksError,
                            loadToken: loadedTrackOffset,
                            action: onLoadMore
                        )
                    }
                }
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: failureMessage)
    }
}

struct StandardMusicCollectionDetailHero: View {
    let artworkURL: URL?
    let title: String
    let subtitle: String
    let metadataText: String
    let tracks: [Song]
    let sourceID: Int
    let isSaved: Bool
    let onToggleSaved: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ArtworkImage(url: artworkURL, cornerRadius: 12)
                .containerRelativeFrame(.horizontal) { width, _ in
                    min(width * 0.68, 300)
                }
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)

            Text(title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 24)
                .padding(.horizontal, 24)

            Text(subtitle)
                .font(.title3)
                .lineLimit(1)
                .padding(.top, 8)

            Text(metadataText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 7)

            MusicCollectionPrimaryActions(
                tracks: tracks,
                sourceID: sourceID,
                isSaved: isSaved,
                onToggleSaved: onToggleSaved
            )
                .padding(.top, 17)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.bottom, 22)
    }
}

private struct ToplistDetailHero: View {
    let playlist: Playlist
    let summary: Playlist?
    let artworkURL: URL?
    let palette: ArtworkDetailPalette

    @Environment(LibraryStore.self) private var library

    var body: some View {
        VStack(spacing: 0) {
            ArtworkImage(url: artworkURL, cornerRadius: 0)
                .containerRelativeFrame(.horizontal)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            .clear,
                            palette.backgroundColor.opacity(0.34),
                            palette.backgroundColor,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 126)
                }

            Text(playlist.name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)
                .padding(.top, 17)

            Text(creatorName)
                .font(.title3)
                .lineLimit(1)
                .padding(.top, 6)

            if let updateText {
                Text(updateText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }

            MusicCollectionPrimaryActions(
                tracks: playlist.tracks,
                sourceID: playlist.id,
                isSaved: library.contains(playlist: playlist),
                onToggleSaved: {
                    library.toggle(playlist: playlist)
                }
            )
                .padding(.top, 17)

            if let descriptionText {
                ExpandablePlaylistDescription(description: descriptionText)
                    .padding(.top, 27)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
    }

    private var creatorName: String {
        playlist.creator?.nickname
            ?? summary?.creator?.nickname
            ?? "网易云音乐"
    }

    private var updateText: String? {
        playlist.updateFrequency?.nonempty
            ?? summary?.updateFrequency?.nonempty
    }

    private var descriptionText: String? {
        playlist.nonemptyDescription
            ?? summary?.nonemptyDescription
            ?? playlist.copywriter?.nonempty
            ?? summary?.copywriter?.nonempty
    }
}

struct MusicCollectionPrimaryActions: View {
    let tracks: [Song]
    let sourceID: Int
    let isSaved: Bool
    let onToggleSaved: () -> Void

    @Environment(PlayerStore.self) private var player
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    Task {
                        await player.playAll(tracks.shuffled(), sourceID: sourceID)
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title2.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .disabled(tracks.isEmpty)
                .accessibilityLabel("随机播放")

                Button {
                    Task { await player.playAll(tracks, sourceID: sourceID) }
                } label: {
                    Label("播放", systemImage: "play.fill")
                        .font(.title3.weight(.bold))
                        .frame(minWidth: 116)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(primaryActionBackground)
                .foregroundStyle(primaryActionForeground)
                .disabled(tracks.isEmpty)

                Button(action: onToggleSaved) {
                    Image(
                        systemName: isSaved ? "checkmark" : "plus"
                    )
                    .font(.title2.weight(.semibold))
                    .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel(isSaved ? "取消收藏" : "收藏")
            }
        }
    }

    private var primaryActionBackground: Color {
        colorScheme == .dark ? .white : .black
    }

    private var primaryActionForeground: Color {
        colorScheme == .dark ? .black : .white
    }
}

private struct ExpandablePlaylistDescription: View {
    let description: String

    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            Text("\(description)  \(Text(isExpanded ? "收起" : "更多").bold())")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(isExpanded ? nil : 3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityLabel(isExpanded ? "收起歌单简介" : "展开歌单简介")
    }
}

struct MusicCollectionArtworkBackdrop: View {
    let blurredArtworkImage: CGImage?
    let palette: ArtworkDetailPalette

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                palette.backgroundColor

                if let blurredArtworkImage {
                    Image(decorative: blurredArtworkImage, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .opacity(0.22)
                        .transition(.opacity)
                }

                LinearGradient(
                    colors: backdropOverlayColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var backdropOverlayColors: [Color] {
        if palette.prefersDarkAppearance {
            return [
                .black.opacity(0.08),
                .black.opacity(0.24),
                .black.opacity(0.40),
            ]
        }
        return [
            .white.opacity(0.06),
            .white.opacity(0.16),
            .white.opacity(0.30),
        ]
    }
}

private extension Playlist {
    var nonemptyDescription: String? {
        playlistDescription?.nonempty
    }
}

private extension String {
    var nonempty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension Int {
    var compactPlayCount: String {
        switch self {
        case 100_000_000...:
            return String(format: "%.1f 亿", Double(self) / 100_000_000)
        case 10_000...:
            return String(format: "%.1f 万", Double(self) / 10_000)
        default:
            return formatted()
        }
    }
}
