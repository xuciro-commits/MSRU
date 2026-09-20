//
//  ProviderDetailView.swift
//  MSRU
//

import SwiftUI
import Observation

struct ProviderDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable var store: ProviderManagerStore
    let providerID: UUID

    var body: some View {
        Group {
            if let provider {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: provider.systemImage)
                                .font(.largeTitle)
                                .frame(width: 44)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(provider.name).font(.title2.bold())
                                Text(provider.summary).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle(
                                "已启用",
                                isOn: Binding(
                                    get: { provider.isEnabled },
                                    set: { store.setEnabled($0, id: provider.id) }
                                )
                            )
                            .toggleStyle(.switch)
                        }

                        GroupBox("配置") {
                            VStack(spacing: 14) {
                                if provider.isCustom {
                                    LabeledContent("名称") {
                                        TextField(
                                            "服务提供方名称",
                                            text: Binding(
                                                get: { provider.name },
                                                set: { store.setName($0, id: provider.id) }
                                            )
                                        )
                                        .frame(maxWidth: 280)
                                    }
                                    LabeledContent("URL") {
                                        TextField(
                                            "https://...",
                                            text: Binding(
                                                get: { provider.endpoint ?? "" },
                                                set: { store.setEndpoint($0, id: provider.id) }
                                            )
                                        )
                                        .frame(maxWidth: 360)
                                    }
                                } else {
                                    LabeledContent("类型", value: "内置")
                                    if let endpoint = provider.endpoint {
                                        LabeledContent("端点", value: endpoint)
                                    }
                                }

                                LabeledContent("优先级") {
                                    Stepper(
                                        value: Binding(
                                            get: { provider.priority },
                                            set: { store.setPriority($0, id: provider.id) }
                                        ),
                                        in: 0...999
                                    ) {
                                        Text("\(provider.priority)").monospacedDigit()
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        GroupBox("能力") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(ManagedProviderCapability.allCases) { capability in
                                    if provider.isCustom {
                                        Toggle(
                                            capability.title,
                                            isOn: Binding(
                                                get: { provider.capabilities.contains(capability) },
                                                set: {
                                                    store.setCapability(
                                                        capability,
                                                        enabled: $0,
                                                        id: provider.id
                                                    )
                                                }
                                            )
                                        )
                                    } else if provider.capabilities.contains(capability) {
                                        Label(capability.title, systemImage: "checkmark.circle.fill")
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }

                        GroupBox("连接") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label(provider.healthTitle, systemImage: healthSymbol(provider))
                                    Spacer()
                                    if store.isTesting(id: provider.id) {
                                        ProgressView().controlSize(.small)
                                    }
                                }
                                if let message = provider.lastTestMessage {
                                    Text(message)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                Button("测试连接") {
                                    Task { await store.testConnection(id: provider.id) }
                                }
                                .disabled(store.isTesting(id: provider.id))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }

                        if provider.isRemovable {
                            Divider()
                            Button("移除服务提供方", role: .destructive) {
                                store.remove(id: provider.id)
                                dismiss()
                            }
                        }
                    }
                    .padding(24)
                }
                .scrollIndicators(.hidden)
            } else {
                ContentUnavailableView("服务提供方已移除", systemImage: "network.slash")
            }
        }
        .frame(minWidth: 560, minHeight: 560)
    }

    private var provider: ManagedProvider? {
        store.provider(id: providerID)
    }

    private func healthSymbol(_ provider: ManagedProvider) -> String {
        switch provider.health {
        case .unknown: "questionmark.circle"
        case .available: "checkmark.circle.fill"
        case .unavailable: "exclamationmark.triangle.fill"
        }
    }
}

#Preview("ProviderDetailView") {
    let store = MSRUPreviewData.makeProviderStore()
    ProviderDetailView(store: store, providerID: store.orderedProviders[0].id)
        .frame(width: 640, height: 560)
}
