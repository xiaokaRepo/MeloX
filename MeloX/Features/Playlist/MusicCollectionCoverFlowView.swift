import Nuke
import NukeUI
import SwiftUI

struct MusicCollectionCoverFlowView: View {
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
    let onInterfaceInteraction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player

    @State private var selectedSongID: Song.ID?
    @State private var selectedPalette: ArtworkDetailPalette?

    var body: some View {
        ZStack {
            if let artworkURL = selectedSong?.album?.artworkURL {
                CoverFlowArtworkBackdrop(artworkURL: artworkURL)
                    .id(selectedSong?.id)
                    .transition(.opacity)
            }

            if isLoading {
                ProgressView(loadingTitle)
                    .tint(.primary)
                    .foregroundStyle(.secondary)
            } else if let failureMessage {
                ConnectionUnavailableView(
                    message: failureMessage,
                    retry: onRetry
                )
                .frame(maxWidth: 420)
            } else if tracks.isEmpty {
                ContentUnavailableView(
                    "暂无歌曲",
                    systemImage: "rectangle.on.rectangle"
                )
                .foregroundStyle(.primary)
            } else {
                GeometryReader { proxy in
                    let artworkSide = min(
                        proxy.size.height * 0.57,
                        proxy.size.width * 0.38,
                        430
                    )

                    VStack(spacing: 0) {
                        CoverFlowCarousel(
                            tracks: tracks,
                            sourceID: sourceID,
                            artworkSide: artworkSide,
                            viewportWidth: proxy.size.width,
                            selectedSongID: $selectedSongID,
                            hasMoreTracks: hasMoreTracks,
                            loadedTrackOffset: loadedTrackOffset,
                            isLoadingMoreTracks: isLoadingMoreTracks,
                            loadMoreTracksError: loadMoreTracksError,
                            onLoadMore: onLoadMore
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if let selectedSong {
                            CoverFlowSelectionLabel(
                                song: selectedSong,
                                palette: selectedPalette
                            )
                                .padding(.horizontal, 80)
                                .padding(.bottom, 48)
                        }
                    }
                    .safeAreaPadding(.top, 34)
                }
            }
        }
        .onAppear {
            synchronizeSelection()
        }
        .onChange(of: tracks.count) {
            synchronizeSelection()
        }
        .onChange(of: player.currentSong?.id) { _, songID in
            guard let songID, tracks.contains(where: { $0.id == songID }) else {
                return
            }

            if accessibilityReduceMotion {
                selectedSongID = songID
            } else {
                withAnimation(.snappy(duration: 0.38, extraBounce: 0)) {
                    selectedSongID = songID
                }
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                onInterfaceInteraction()
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 8).onEnded { _ in
                onInterfaceInteraction()
            }
        )
        .task(id: selectedSong?.id) {
            guard let artworkURL = selectedSong?.album?.artworkURL else {
                selectedPalette = nil
                return
            }

            selectedPalette = ArtworkAccentColorProvider.cachedDetailAssets(
                for: artworkURL
            )?.palette
            let assets = await ArtworkAccentColorProvider.shared.detailAssets(
                for: artworkURL,
                fallbackPrefersDarkAppearance: true
            )
            guard !Task.isCancelled else { return }
            selectedPalette = assets.palette
        }
        .animation(
            accessibilityReduceMotion ? nil : .easeInOut(duration: 0.48),
            value: selectedSongID
        )
        .preferredColorScheme(.dark)
    }

    private var selectedSong: Song? {
        guard let selectedSongID else { return tracks.first }
        return tracks.first { $0.id == selectedSongID }
    }

    private func synchronizeSelection() {
        if let currentSongID = player.currentSong?.id,
           tracks.contains(where: { $0.id == currentSongID }) {
            selectedSongID = currentSongID
        } else if selectedSongID == nil
                    || !tracks.contains(where: { $0.id == selectedSongID }) {
            selectedSongID = tracks.first?.id
        }
    }
}

private struct CoverFlowCarousel: View {
    let tracks: [Song]
    let sourceID: Int
    let artworkSide: CGFloat
    let viewportWidth: CGFloat
    @Binding var selectedSongID: Song.ID?
    let hasMoreTracks: Bool
    let loadedTrackOffset: Int
    let isLoadingMoreTracks: Bool
    let loadMoreTracksError: String?
    let onLoadMore: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player

    var body: some View {
        let reducesMotion = accessibilityReduceMotion

        ScrollView(.horizontal) {
            LazyHStack(spacing: -max(artworkSide * 0.14, 22)) {
                ForEach(tracks) { song in
                    CoverFlowArtworkCard(
                        song: song,
                        artworkSide: artworkSide,
                        isCurrentSong: player.currentSong?.id == song.id,
                        isPlaying: player.isPlaying,
                        action: { selectAndPlay(song) }
                    )
                    .id(song.id)
                    .zIndex(selectedSongID == song.id ? 1 : 0)
                    .scrollTransition(.interactive, axis: .horizontal) {
                        content,
                        phase in
                        content
                            .scaleEffect(
                                reducesMotion
                                    ? 1
                                    : 1 - min(abs(phase.value), 1) * 0.24
                            )
                            .rotation3DEffect(
                                .degrees(
                                    reducesMotion
                                        ? 0
                                        : Double(phase.value) * -58
                                ),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.62
                            )
                            .offset(
                                x: reducesMotion
                                    ? 0
                                    : phase.value * -artworkSide * 0.08
                            )
                            .opacity(
                                reducesMotion
                                    ? 1
                                    : 1 - min(abs(phase.value), 1) * 0.28
                            )
                    }
                }

                if hasMoreTracks {
                    CoverFlowLoadMoreCard(
                        loadedTrackOffset: loadedTrackOffset,
                        isLoading: isLoadingMoreTracks,
                        failureMessage: loadMoreTracksError,
                        action: onLoadMore
                    )
                    .frame(width: max(artworkSide * 0.64, 150))
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(
            .horizontal,
            max((viewportWidth - artworkSide) / 2, 24),
            for: .scrollContent
        )
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $selectedSongID, anchor: .center)
    }

    private func selectAndPlay(_ song: Song) {
        if accessibilityReduceMotion {
            selectedSongID = song.id
        } else {
            withAnimation(.snappy(duration: 0.38, extraBounce: 0)) {
                selectedSongID = song.id
            }
        }

        if player.currentSong?.id == song.id {
            player.togglePlayback()
        } else {
            Task {
                await player.play(song, in: tracks, sourceID: sourceID)
            }
        }
    }
}

private struct CoverFlowArtworkBackdrop: View {
    let artworkURL: URL

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        GeometryReader { proxy in
            LazyImage(
                request: imageRequest(for: proxy.size),
                transaction: Transaction(
                    animation: accessibilityReduceMotion
                        ? nil
                        : .easeInOut(duration: 0.42)
                )
            ) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.clear
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(1.28)
            .blur(radius: 46, opaque: true)
            .saturation(1.18)
            .overlay {
                Color.black.opacity(0.42)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func imageRequest(for size: CGSize) -> ImageRequest {
        var request = ImageRequest(url: artworkURL)
        request.thumbnail = ImageRequest.ThumbnailOptions(
            size: CGSize(
                width: max(size.width * 1.3, 1),
                height: max(size.height * 1.3, 1)
            ),
            contentMode: .aspectFill
        )
        return request
    }
}

private struct CoverFlowArtworkCard: View {
    let song: Song
    let artworkSide: CGFloat
    let isCurrentSong: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack {
                    ArtworkImage(
                        url: song.album?.artworkURL,
                        cornerRadius: 4
                    )
                    .frame(width: artworkSide, height: artworkSide)
                    .shadow(color: .black.opacity(0.42), radius: 22, y: 13)

                    if isCurrentSong {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2.weight(.bold))
                            .frame(width: 52, height: 52)
                            .glassEffect(.regular, in: .circle)
                    }
                }

                ArtworkImage(
                    url: song.album?.artworkURL,
                    cornerRadius: 0
                )
                .frame(width: artworkSide, height: artworkSide)
                .scaleEffect(y: -1)
                .frame(height: artworkSide * 0.16, alignment: .top)
                .clipped()
                .mask {
                    LinearGradient(
                        colors: [.white.opacity(0.34), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .opacity(0.55)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(song.name)，\(song.artistText)")
        .accessibilityHint("播放歌曲")
        .accessibilityValue(isCurrentSong ? "正在播放" : "")
    }
}

private struct CoverFlowSelectionLabel: View {
    let song: Song
    let palette: ArtworkDetailPalette?

    var body: some View {
        VStack(spacing: 3) {
            Text(song.name)
                .font(.headline)
                .foregroundStyle(titleColor)
                .shadow(color: .black.opacity(0.55), radius: 5, y: 2)
                .lineLimit(1)

            Text(song.artistText)
                .font(.caption)
                .foregroundStyle(titleColor.opacity(0.78))
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                .lineLimit(1)
        }
        .frame(maxWidth: 420)
        .contentTransition(.opacity)
        .accessibilityElement(children: .combine)
    }

    private var titleColor: Color {
        guard let accent = palette?.accentRGB else { return .white }
        return Color(red: accent.x, green: accent.y, blue: accent.z)
    }
}

private struct CoverFlowLoadMoreCard: View {
    let loadedTrackOffset: Int
    let isLoading: Bool
    let failureMessage: String?
    let action: () async -> Void

    var body: some View {
        MusicCollectionPaginationFooter(
            isLoading: isLoading,
            failureMessage: failureMessage,
            loadToken: loadedTrackOffset,
            action: action
        )
        .frame(maxHeight: 180)
        .foregroundStyle(.white)
        .background(.black.opacity(0.48), in: .rect(cornerRadius: 8))
    }
}
