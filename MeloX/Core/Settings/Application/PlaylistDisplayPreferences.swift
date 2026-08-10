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

enum PlaylistLandscapeDisplayMode: String, CaseIterable, Identifiable {
    case posterWall
    case coverFlow

    var id: Self { self }

    var title: String {
        switch self {
        case .posterWall:
            "封面墙"
        case .coverFlow:
            "Cover Flow"
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
        static let motionSpeed =
            "melox.playlist.posterWall.motionSpeed"
        static let randomFlipEnabled =
            "melox.playlist.posterWall.randomFlipEnabled"
        static let landscapeMode =
            "melox.playlist.landscape.display.mode"
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

    var motionSpeed: Double {
        didSet { defaults.set(motionSpeed, forKey: Key.motionSpeed) }
    }

    var randomFlipEnabled: Bool {
        didSet {
            defaults.set(randomFlipEnabled, forKey: Key.randomFlipEnabled)
        }
    }

    var landscapeMode: PlaylistLandscapeDisplayMode {
        didSet {
            defaults.set(landscapeMode.rawValue, forKey: Key.landscapeMode)
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
        motionSpeed = min(
            max(defaults.object(forKey: Key.motionSpeed) as? Double ?? 1, 0.5),
            2
        )
        randomFlipEnabled = defaults.object(
            forKey: Key.randomFlipEnabled
        ) as? Bool ?? true
        landscapeMode = PlaylistLandscapeDisplayMode(
            rawValue: defaults.string(forKey: Key.landscapeMode) ?? ""
        ) ?? .coverFlow
    }

    func reset() {
        mode = .list
        horizontalMotionEnabled = true
        verticalMotionEnabled = true
        motionSpeed = 1
        randomFlipEnabled = true
        landscapeMode = .coverFlow
    }
}
