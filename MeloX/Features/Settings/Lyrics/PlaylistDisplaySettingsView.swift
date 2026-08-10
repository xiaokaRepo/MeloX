import SwiftUI

struct PlaylistDisplaySettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var playlistDisplay = settings.playlistDisplay

        Form {
            Section {
                Picker("默认展示方式", selection: $playlistDisplay.mode) {
                    ForEach(PlaylistDisplayMode.allCases) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("歌单展示")
            } footer: {
                Text("封面墙模式会在打开歌单时直接进入全屏拼贴视图，仍可随时返回列表。")
            }

            Section {
                Toggle(
                    "左右漂移",
                    systemImage: "arrow.left.and.right",
                    isOn: $playlistDisplay.horizontalMotionEnabled
                )

                Toggle(
                    "上下漂移",
                    systemImage: "arrow.up.and.down",
                    isOn: $playlistDisplay.verticalMotionEnabled
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("漂移速度", systemImage: "speedometer")
                        Spacer()
                        Text(
                            playlistDisplay.motionSpeed,
                            format: .number.precision(.fractionLength(2))
                        )
                        .monospacedDigit()
                        Text("x")
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $playlistDisplay.motionSpeed,
                        in: 0.5...2,
                        step: 0.25
                    )
                    .accessibilityLabel("漂移速度")
                    .accessibilityValue(
                        "\(playlistDisplay.motionSpeed.formatted(.number.precision(.fractionLength(2))))倍"
                    )
                }
                .disabled(
                    !playlistDisplay.horizontalMotionEnabled
                        && !playlistDisplay.verticalMotionEnabled
                )

                Toggle(
                    "随机翻面",
                    systemImage: "rectangle.portrait.rotate",
                    isOn: $playlistDisplay.randomFlipEnabled
                )
            } header: {
                Text("封面墙动态效果")
            } footer: {
                Text("左右与上下漂移会移动整面封面墙。系统开启“减少动态效果”时会自动暂停。")
            }

            Section {
                Picker(
                    "横屏展示",
                    selection: $playlistDisplay.landscapeMode
                ) {
                    ForEach(PlaylistLandscapeDisplayMode.allCases) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("横屏效果")
            } footer: {
                Text("仅在设备横屏并打开歌单视觉视图时生效。Cover Flow 可横向滑动，点击封面即可播放。")
            }
        }
        .navigationTitle("歌单与封面墙")
        .navigationBarTitleDisplayMode(.inline)
    }
}
