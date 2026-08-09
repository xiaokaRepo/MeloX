@preconcurrency import AVFoundation

@MainActor
final class AudioPlaybackItemFactory {
    private let equalizerProcessor:
        AudioEqualizerProcessor

    init(
        equalizerConfiguration:
            AudioEqualizerConfiguration
    ) {
        equalizerProcessor = AudioEqualizerProcessor(
            configuration: equalizerConfiguration
        )
    }

    func makeItem(
        for source: PlaybackSource,
        preferredForwardBufferDuration: TimeInterval,
        autoMixEqualizerState:
            SharedAutoMixEqualizerState
    ) async -> AVPlayerItem {
        let options: [String: Any]? = source.httpHeaders.isEmpty
            ? nil
            : ["AVURLAssetHTTPHeaderFieldsKey": source.httpHeaders]
        let asset = AVURLAsset(url: source.url, options: options)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration =
            max(
                preferredForwardBufferDuration,
                source.preferredForwardBufferDuration
            )
        item.allowedAudioSpatializationFormats = .multichannel
        do {
            if let audioTrack = try await asset.loadTracks(
                withMediaType: .audio
            ).first {
                item.audioMix =
                    equalizerProcessor.makeAudioMix(
                        for: audioTrack,
                        autoMixEqualizerState:
                            autoMixEqualizerState
                    )
            }
        } catch {
            // AVPlayerItem reports an actionable error if playback fails.
        }
        return item
    }

    func updateEqualizer(
        _ configuration: AudioEqualizerConfiguration
    ) {
        equalizerProcessor.update(
            configuration: configuration
        )
    }
}
