//
//  AddProviderView.swift
//  MSRU
//

import SwiftUI
import Observation

struct AddProviderView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var store: ProviderManagerStore

    @State private var name = ""
    @State private var endpoint = ""
    @State private var catalog = true
    @State private var metadata = false
    @State private var playback = false
    @State private var library = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("添加服务提供方").font(.title2.bold())
                Text("注册远程 HTTP/JSON 服务提供方配置。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Form {
                Section("服务提供方") {
                    TextField("名称", text: $name)
                    TextField("服务提供方或清单 URL", text: $endpoint)
                }
                Section("能力") {
                    Toggle("目录", isOn: $catalog)
                    Toggle("元数据", isOn: $metadata)
                    Toggle("播放", isOn: $playback)
                    Toggle("资料库", isOn: $library)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("添加服务提供方") {
                    let id = store.addRemoteProvider(
                        name: name,
                        endpoint: endpoint,
                        capabilities: selectedCapabilities
                    )
                    Task { await store.testConnection(id: id) }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdd)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 500)
    }

    private var selectedCapabilities: Set<ManagedProviderCapability> {
        var result: Set<ManagedProviderCapability> = []
        if catalog { result.insert(.catalog) }
        if metadata { result.insert(.metadata) }
        if playback { result.insert(.playback) }
        if library { result.insert(.library) }
        return result
    }

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && ProviderManagerStore.validHTTPURL(endpoint) != nil
        && !selectedCapabilities.isEmpty
    }
}

#Preview("AddProviderView") {
    AddProviderView(store: MSRUPreviewData.makeProviderStore())
}
