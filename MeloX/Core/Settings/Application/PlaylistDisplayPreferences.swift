import Foundation
import Observation

enum PlaylistDisplayMode: String, CaseIterable, Identifiable {
    case list
    case posterWall

    var id: Self { self }

    var title: String {
        switch self {
        case .list:
            "列表展示"
        case .posterWall:
            "封面墙展示"
        }
    }
}

@MainActor
@Observable
final class PlaylistDisplayPreferences {
    private enum Key {
        static let mode = "melox.playlist.display.mode"
        static let horizontalMotionEnabled =
            "melox.playlist.posterWall.horizontalMotionEnabled"
        static let verticalMotionEnabled =
            "melox.playlist.posterWall.verticalMotionEnabled"
        static let randomFlipEnabled =
            "melox.playlist.posterWall.randomFlipEnabled"
    }

    var mode: PlaylistDisplayMode {
        didSet { defaults.set(mode.rawValue, forKey: Key.mode) }
    }

    var horizontalMotionEnabled: Bool {
        didSet {
            defaults.set(
                horizontalMotionEnabled,
                forKey: Key.horizontalMotionEnabled
            )
        }
    }

    var verticalMotionEnabled: Bool {
        didSet {
            defaults.set(
                verticalMotionEnabled,
                forKey: Key.verticalMotionEnabled
            )
        }
    }

    var randomFlipEnabled: Bool {
        didSet {
            defaults.set(randomFlipEnabled, forKey: Key.randomFlipEnabled)
        }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = PlaylistDisplayMode(
            rawValue: defaults.string(forKey: Key.mode) ?? ""
        ) ?? .list
        horizontalMotionEnabled = defaults.object(
            forKey: Key.horizontalMotionEnabled
        ) as? Bool ?? true
        verticalMotionEnabled = defaults.object(
            forKey: Key.verticalMotionEnabled
        ) as? Bool ?? true
        randomFlipEnabled = defaults.object(
            forKey: Key.randomFlipEnabled
        ) as? Bool ?? true
    }

    func reset() {
        mode = .list
        horizontalMotionEnabled = true
        verticalMotionEnabled = true
        randomFlipEnabled = true
    }
}
