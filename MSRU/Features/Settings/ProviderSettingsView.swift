//
//  ProviderSettingsView.swift
//  MSRU
//

import SwiftUI
import Observation

struct ProviderSettingsView: View {

    @Bindable var store: ProviderManagerStore
    @State private var isAddingProvider = false
    @State private var selectedProviderID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已配置的服务提供方").font(.title3.bold())
                    Text("分别配置目录、元数据、资料库和播放能力。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isAddingProvider = true
                } label: {
                    Label("添加服务提供方", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            let providers = store.orderedProviders
            VStack(spacing: 0) {
                ForEach(providers) { provider in
                    HStack(alignment: .center, spacing: 14) {
                        Button {
                            selectedProviderID = provider.id
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: provider.systemImage)
                                    .font(.title2)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(provider.name).font(.headline)
                                        Text(provider.healthTitle)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.quaternary, in: Capsule())
                                    }
                                    Text(provider.summary)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 6) {
                                        ForEach(provider.capabilities.sorted { $0.rawValue < $1.rawValue }) { capability in
                                            Text(capability.title)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(.quaternary, in: Capsule())
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Toggle(
                            "已启用",
                            isOn: Binding(
                                get: { provider.isEnabled },
                                set: { store.setEnabled($0, id: provider.id) }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    .padding(16)

                    if provider.id != providers.last?.id { Divider() }
                }
            }
            .background(
                .quaternary,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("播放优先级").font(.title3.bold())
                let playback = store.playbackProviders
                VStack(spacing: 0) {
                    ForEach(playback) { provider in
                        HStack(spacing: 12) {
                            Text("\(provider.priority)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .trailing)
                            Image(systemName: provider.systemImage).frame(width: 24)
                            Text(provider.name)
                            Spacer()
                            Text(provider.isEnabled ? "已启用" : "已停用")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        if provider.id != playback.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .background(
                    .quaternary,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
        }
        .sheet(isPresented: $isAddingProvider) {
            AddProviderView(store: store)
        }
        .sheet(isPresented: detailIsPresented) {
            if let selectedProviderID {
                ProviderDetailView(store: store, providerID: selectedProviderID)
            }
        }
    }

    private var detailIsPresented: Binding<Bool> {
        Binding(
            get: { selectedProviderID != nil },
            set: { if !$0 { selectedProviderID = nil } }
        )
    }
}

#Preview {
    ScrollView {
        ProviderSettingsView(store: MSRUPreviewData.makeProviderStore())
            .padding(28)
    }
    .scrollIndicators(.hidden)
    .frame(width: 900, height: 760)
}
