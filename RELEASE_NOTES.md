# MeloX Release Notes / MeloX 更新日志

## iOS + Apple Watch

### 简体中文

- 增加了一比一还原的“Apple Music 26“歌词样式并作为默认值，之前的样式可切换至“自定义“样式后重新使用
- 增加了全新的“Apple Music“样式播放器背景，基于Apple Music 26一比一还原，可在设置中切换
- 增加了双人歌词对唱展示的支持
- 增加了多源歌词优选（网易云、99音乐、AMLL）
- 添加蜂窝网络音质设置 by takoyakiwhite
- 修复了播放列表只会添加歌单前100首歌的问题
- 修复了播放器内前往艺人只能选择第一个艺人的问题 by takoyakiwhite
- 修复了自动混音执行时会卡顿一秒的问题 by takoyakiwhite
- 增加了多声部同时唱词，主唱与独立声部在重叠段落可同时展示并分别逐字高亮
- 增强了 TTML 歌词解析，支持声部标记、嵌套背景和声、逐字时间、翻译和音译
- 提升了 Apple Watch 逐字歌词的获取和回退稳定性
- 修复了外接蓝牙音频设备断开后播放不会自动暂停的问题
- 优化了播放器菜单，将歌词源选择收纳至子菜单

### English

- Added a one-to-one recreation of the Apple Music 26 lyric style as the default; the previous style can be restored by switching back to the Custom style in Settings
- Added a new Apple Music-style player background recreated from Apple Music 26, selectable in Settings
- Added support for displaying duet lyrics
- Added multi-source lyric preference across NetEase Cloud Music, 99 Music, and AMLL
- Added a cellular-network audio quality setting by takoyakiwhite
- Fixed an issue where playlists only added their first 100 songs
- Fixed an issue where navigating to an artist from the player only offered the first artist by takoyakiwhite
- Fixed a one-second stutter during automatic mixing by takoyakiwhite
- Added simultaneous multi-vocal lyrics, allowing lead and independent vocal parts to remain visible and highlight their own words during overlapping sections
- Expanded TTML lyric parsing with support for vocal-part markers, nested background vocals, word timing, translations, and romanization
- Improved word-synced lyric fetching and fallback reliability on Apple Watch
- Fixed an issue where playback did not pause automatically after a connected Bluetooth audio device disconnected
- Refined the player menu by moving lyric source selection into a submenu

## macOS

### 简体中文

- 增加了 Dock 图标右键菜单的播放控制项
- 修复了 macOS 媒体暂停键无法暂停 MeloX 播放的问题
- 修复了 macOS 播放器收藏按钮点按后状态未实时刷新的问题
- 增加了多声部同时唱词，主唱与独立声部在重叠段落可同时展示并分别逐字高亮
- 增强了 TTML 歌词解析，支持声部标记、嵌套背景和声、逐字时间、翻译和音译

### English

- Added playback controls to the Dock icon’s context menu
- Fixed an issue where the macOS media pause key could not pause MeloX playback
- Fixed an issue where the macOS player’s favorite button did not update immediately after being clicked
- Added simultaneous multi-vocal lyrics, allowing lead and independent vocal parts to remain visible and highlight their own words during overlapping sections
- Expanded TTML lyric parsing with support for vocal-part markers, nested background vocals, word timing, translations, and romanization
