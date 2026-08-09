import SwiftUI

struct GatewaySettingsView: View {
    @Environment(GatewayProviderStore.self) private var gateway

    @State private var baseURL = ""
    @State private var token = ""
    @State private var isEnabled = false
    @State private var didLoadDraft = false

    var body: some View {
        Form {
            GatewayConnectionSection(
                baseURL: $baseURL,
                token: $token,
                isEnabled: $isEnabled,
                hasSavedToken: gateway.hasToken,
                connectionState: gateway.connectionState,
                saveAction: saveConnection
            )

            GatewayProvidersSection(
                providers: gateway.providers,
                checkingProviderIDs: gateway.checkingProviderIDs,
                isConfigured: gateway.isEnabled
                    && !gateway.baseURL.isEmpty
                    && gateway.hasToken,
                toggleProvider: toggleProvider,
                checkProvider: checkProvider,
                moveProviders: moveProviders
            )

            GatewayAdministrationSection(baseURL: gateway.baseURL)
        }
        .navigationTitle("自定义音源")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if gateway.providers.count > 1 {
                EditButton()
            }
        }
        .refreshable {
            await gateway.refresh()
        }
        .task {
            guard !didLoadDraft else { return }
            didLoadDraft = true
            baseURL = gateway.baseURL
            isEnabled = gateway.isEnabled
            if gateway.isEnabled
                && !gateway.baseURL.isEmpty
                && gateway.hasToken {
                await gateway.refresh()
            }
        }
        .alert(
            "Gateway 请求失败",
            isPresented: Binding(
                get: { gateway.lastErrorMessage != nil },
                set: { if !$0 { gateway.dismissError() } }
            )
        ) {
            Button("好", role: .cancel) {
                gateway.dismissError()
            }
        } message: {
            Text(gateway.lastErrorMessage ?? "未知错误")
        }
    }

    private func saveConnection() {
        Task {
            await gateway.configure(
                baseURL: baseURL,
                token: token,
                enabled: isEnabled
            )
            if gateway.lastErrorMessage == nil {
                token = ""
            }
        }
    }

    private func toggleProvider(_ providerID: String, enabled: Bool) {
        Task {
            await gateway.setProvider(providerID, enabled: enabled)
        }
    }

    private func checkProvider(_ providerID: String) {
        Task {
            await gateway.checkProvider(providerID)
        }
    }

    private func moveProviders(_ source: IndexSet, _ destination: Int) {
        var reordered = gateway.providers
        reordered.move(fromOffsets: source, toOffset: destination)
        Task {
            await gateway.reorderProviders(reordered.map(\.id))
        }
    }
}

private struct GatewayConnectionSection: View {
    @Binding var baseURL: String
    @Binding var token: String
    @Binding var isEnabled: Bool

    let hasSavedToken: Bool
    let connectionState: GatewayConnectionState
    let saveAction: () -> Void

    var body: some View {
        Section {
            Toggle("启用 Gateway", isOn: $isEnabled)

            TextField(
                "例如 http://192.168.1.10:8787",
                text: $baseURL,
                prompt: Text("Gateway 地址")
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            SecureField(
                hasSavedToken ? "已安全保存，留空则保持不变" : "Client Token",
                text: $token
            )
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            GatewayConnectionStatusRow(state: connectionState)

            Button(action: saveAction) {
                Label("保存并测试连接", systemImage: "bolt.horizontal.circle")
            }
            .disabled(
                isEnabled
                    && (baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || (!hasSavedToken
                            && token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            )
        } header: {
            Text("连接")
        } footer: {
            Text("请填写管理台签发的 Client Token，不要填写管理员密码或音源 API Key。Token 只保存在本机安全存储中。")
        }
    }
}

private struct GatewayConnectionStatusRow: View {
    let state: GatewayConnectionState

    var body: some View {
        LabeledContent("状态") {
            HStack(spacing: 6) {
                if case .connecting = state {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: state.systemImage)
                        .foregroundStyle(color)
                }
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detail: String {
        if case let .connected(latencyMS) = state {
            return "\(state.title) · \(latencyMS) ms"
        }
        return state.title
    }

    private var color: Color {
        switch state {
        case .connected: .green
        case .failed: .red
        case .connecting: .orange
        case .disabled, .notConfigured: .secondary
        }
    }
}

private struct GatewayProvidersSection: View {
    let providers: [GatewayProvider]
    let checkingProviderIDs: Set<String>
    let isConfigured: Bool
    let toggleProvider: (String, Bool) -> Void
    let checkProvider: (String) -> Void
    let moveProviders: (IndexSet, Int) -> Void

    var body: some View {
        Section {
            if !isConfigured {
                Label(
                    "配置并启用 Gateway 后可管理 Provider",
                    systemImage: "server.rack"
                )
                .foregroundStyle(.secondary)
            } else if providers.isEmpty {
                Label(
                    "Gateway 中还没有 Provider",
                    systemImage: "externaldrive.badge.plus"
                )
                .foregroundStyle(.secondary)
            } else {
                ForEach(Array(providers.enumerated()), id: \.element.id) {
                    index, provider in
                    GatewayProviderRow(
                        provider: provider,
                        position: index + 1,
                        isChecking: checkingProviderIDs.contains(provider.id),
                        toggleAction: { enabled in
                            toggleProvider(provider.id, enabled)
                        },
                        checkAction: {
                            checkProvider(provider.id)
                        }
                    )
                }
                .onMove(perform: moveProviders)
            }
        } header: {
            Text("Provider")
        } footer: {
            if providers.count > 1 {
                Text("点按右上角“编辑”后拖动排序。排序决定候选优先级，并行解析时仍返回最先验证通过的 Provider。")
            } else {
                Text("点开 Provider 查看完整来源、能力和音质。")
            }
        }
    }
}

private struct GatewayProviderRow: View {
    let provider: GatewayProvider
    let position: Int
    let isChecking: Bool
    let toggleAction: (Bool) -> Void
    let checkAction: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GatewayProviderHeader(
                provider: provider,
                position: position,
                toggleAction: toggleAction
            )

            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    isExpanded.toggle()
                }
            } label: {
                GatewayProviderSummary(provider: provider, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if let error = provider.lastError, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            if isExpanded {
                GatewayProviderDetails(
                    provider: provider,
                    isChecking: isChecking,
                    checkAction: checkAction
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }

}

private struct GatewayProviderHeader: View {
    let provider: GatewayProvider
    let position: Int
    let toggleAction: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("\(position)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.secondary.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(provider.providerType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            GatewayProviderStatusBadge(provider: provider)

            Toggle(
                "启用 \(provider.name)",
                isOn: Binding(
                    get: { provider.enabled },
                    set: toggleAction
                )
            )
            .labelsHidden()
        }
    }
}

private struct GatewayProviderSummary: View {
    let provider: GatewayProvider
    let isExpanded: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            GatewayProviderIconStrip(
                sources: provider.supportedSources,
                qualities: provider.qualities
            )

            if !provider.capabilities.isEmpty {
                Text(provider.capabilities.map(\.title).joined(separator: " / "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let latency = provider.latencyMS, provider.enabled {
                Text("· \(latency) ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityLabel(isExpanded ? "收起详情" : "展开详情")
        }
        .contentShape(Rectangle())
    }
}

private struct GatewayProviderDetails: View {
    let provider: GatewayProvider
    let isChecking: Bool
    let checkAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            GatewayProviderDetailRow(
                icon: "music.note.list",
                title: "来源",
                content: {
                    GatewayProviderIconChips(
                        values: provider.supportedSources,
                        icon: sourceIcon,
                        title: sourceTitle,
                        emptyText: "未声明支持平台"
                    )
                }
            )

            GatewayProviderDetailRow(
                icon: "puzzlepiece.extension",
                title: "能力",
                content: {
                    Text(provider.capabilities.isEmpty
                    ? "未声明能力"
                    : provider.capabilities.map(\.title).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            )

            GatewayProviderDetailRow(
                icon: "waveform.badge.magnifyingglass",
                title: "音质",
                content: {
                    GatewayProviderIconChips(
                        values: provider.qualities,
                        icon: qualityIcon,
                        title: { $0.title },
                        emptyText: "未声明支持音质"
                    )
                }
            )

            Button(action: checkAction) {
                if isChecking {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在检测")
                    }
                } else {
                    Label("检测连接", systemImage: "arrow.clockwise")
                }
            }
            .font(.subheadline)
            .disabled(isChecking || !provider.enabled)
        }
    }

    private func sourceTitle(_ source: String) -> String {
        switch source.lowercased() {
        case "netease": "网易云音乐"
        case "qq": "QQ 音乐"
        case "kugou", "kg": "酷狗音乐"
        case "kuwo", "kw": "酷我音乐"
        case "joox": "JOOX"
        case "bilibili": "哔哩哔哩"
        case "tencent": "腾讯音乐"
        case "tidal": "TIDAL"
        case "qobuz": "Qobuz"
        case "apple": "Apple Music"
        case "ytmusic": "YouTube Music"
        case "spotify": "Spotify"
        default: source
        }
    }

    private func sourceIcon(_ source: String) -> String {
        switch source.lowercased() {
        case "apple": "apple.logo"
        case "bilibili": "play.rectangle"
        case "spotify": "dot.radiowaves.forward"
        case "joox": "j.circle"
        case "qq", "qobuz": "q.circle"
        case "tencent", "tidal": "t.circle"
        case "netease", "kugou", "kuwo", "kw", "ytmusic": "music.note"
        default: "music.note.list"
        }
    }

    private func qualityIcon(_ quality: GatewayQuality) -> String {
        switch quality {
        case .hires, .jymaster:
            "sparkles"
        case .lossless:
            "waveform"
        case .exhigh:
            "dial.high"
        default:
            "waveform.badge.magnifyingglass"
        }
    }
}

private struct GatewayProviderIconStrip: View {
    let sources: [String]
    let qualities: [GatewayQuality]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(sources.prefix(3), id: \.self) { source in
                Image(systemName: sourceIcon(source))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                    .help(sourceTitle(source))
                    .accessibilityLabel(sourceTitle(source))
            }
            if sources.count > 3 {
                Text("+\(sources.count - 3)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            if !qualities.isEmpty {
                Image(systemName: "waveform")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                    .help("支持 \(qualities.count) 档音质")
                    .accessibilityLabel("支持 \(qualities.count) 档音质")
            }
        }
    }

    private func sourceTitle(_ source: String) -> String {
        switch source.lowercased() {
        case "netease": "网易云音乐"
        case "qq": "QQ 音乐"
        case "kugou", "kg": "酷狗音乐"
        case "kuwo", "kw": "酷我音乐"
        case "joox": "JOOX"
        case "bilibili": "哔哩哔哩"
        case "tencent": "腾讯音乐"
        case "tidal": "TIDAL"
        case "qobuz": "Qobuz"
        case "apple": "Apple Music"
        case "ytmusic": "YouTube Music"
        case "spotify": "Spotify"
        default: source
        }
    }

    private func sourceIcon(_ source: String) -> String {
        switch source.lowercased() {
        case "apple": "apple.logo"
        case "bilibili": "play.rectangle"
        case "spotify": "dot.radiowaves.forward"
        case "joox": "j.circle"
        case "qq", "qobuz": "q.circle"
        case "tencent", "tidal": "t.circle"
        default: "music.note"
        }
    }
}

private struct GatewayProviderIconChips<Value: Hashable>: View {
    let values: [Value]
    let icon: (Value) -> String
    let title: (Value) -> String
    let emptyText: String

    init(
        values: [Value],
        icon: @escaping (Value) -> String,
        title: @escaping (Value) -> String,
        emptyText: String
    ) {
        self.values = values
        self.icon = icon
        self.title = title
        self.emptyText = emptyText
    }

    var body: some View {
        if values.isEmpty {
            Text(emptyText)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        Label(title(value), systemImage: icon(value))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.secondary.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
    }
}

private struct GatewayProviderDetailRow<Content: View>: View {
    let icon: String
    let title: String
    let content: Content

    init(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            content
        }
    }
}

private struct GatewayProviderStatusBadge: View {
    let provider: GatewayProvider

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var text: String {
        let status: String
        switch provider.status {
        case "healthy": status = "正常"
        case "degraded": status = "不稳定"
        case "unhealthy": status = "异常"
        case "disabled": status = "已停用"
        default: status = "未检测"
        }
        return status
    }

    private var color: Color {
        switch provider.status {
        case "healthy": .green
        case "degraded": .orange
        case "unhealthy": .red
        default: .secondary
        }
    }
}

private struct GatewayAdministrationSection: View {
    let baseURL: String

    var body: some View {
        Section {
            if let url = URL(string: baseURL), !baseURL.isEmpty {
                Link(destination: url) {
                    Label("打开 Gateway 管理台", systemImage: "safari")
                }
            } else {
                Label("配置地址后可打开管理台", systemImage: "safari")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("高级管理")
        } footer: {
            Text("新增或删除 Provider、修改 Endpoint 和 API Key 仍在 Web 管理台完成，MeloX 不会读取音源密钥。")
        }
    }
}
