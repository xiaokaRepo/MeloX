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

                Toggle(
                    "随机翻面",
                    systemImage: "rectangle.portrait.rotate",
                    isOn: $playlistDisplay.randomFlipEnabled
                )
            } header: {
                Text("封面墙动态效果")
            } footer: {
                Text("动态效果仅影响封面墙。系统开启“减少动态效果”时会自动暂停。")
            }
        }
        .navigationTitle("歌单与封面墙")
        .navigationBarTitleDisplayMode(.inline)
    }
}
