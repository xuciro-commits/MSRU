//
//  ProviderDetailView.swift
//  MSRU
//

import SwiftUI
import Observation
import AppFoundationUI
import MusicLibrary

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
                                Text(LocalizedStringKey(provider.name)).font(.title2.bold())
                                Text(LocalizedStringKey(provider.summary)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle(
                                "Enabled",
                                isOn: Binding(
                                    get: { provider.isEnabled },
                                    set: { store.setEnabled($0, id: provider.id) }
                                )
                            )
                            .toggleStyle(.switch)
                        }

                        GroupBox("Configuration") {
                            VStack(spacing: 14) {
                                if provider.isCustom {
                                    LabeledContent("Name") {
                                        TextField(
                                            "ProvidersName",
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
                                    LabeledContent(String(localized: "Type"), value: String(localized: "Built-in"))
                                    if let endpoint = provider.endpoint {
                                        LabeledContent(String(localized: "Endpoint"), value: endpoint)
                                    }
                                }

                                LabeledContent("Priority") {
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

                        GroupBox("Capabilities") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(ManagedProviderCapability.allCases) { capability in
                                    if provider.isCustom {
                                        Toggle(
                                            LocalizedStringKey(capability.title),
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
                                        Label(LocalizedStringKey(capability.title), systemImage: "checkmark.circle.fill")
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }

                        GroupBox("Connection") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label(LocalizedStringKey(provider.healthTitle), systemImage: healthSymbol(provider))
                                    Spacer()
                                    if store.isTesting(id: provider.id) {
                                        ProgressView().controlSize(.small)
                                    }
                                }
                                if let message = provider.lastTestMessage {
                                    Text(LocalizedStringKey(message))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                Button("Test Connection") {
                                    Task { await store.testConnection(id: provider.id) }
                                }
                                .disabled(store.isTesting(id: provider.id))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }

                        if provider.isRemovable {
                            Divider()
                            Button("Remove Provider", role: .destructive) {
                                store.remove(id: provider.id)
                                dismiss()
                            }
                        }
                    }
                    .padding(24)
                }
                .hideScrollIndicatorsCompletely()
            } else {
                ContentUnavailableView("Provider Removed", systemImage: "network.slash")
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

// MARK: - Add Provider View

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
                Text("Add Provider").font(.title2.bold())
                Text("Register remote HTTP/JSON provider config.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Form {
                Section("Provider") {
                    TextField("Name", text: $name)
                    TextField("Provider or Manifest URL", text: $endpoint)
                }
                Section("Capabilities") {
                    Toggle("Catalog", isOn: $catalog)
                    Toggle("Metadata", isOn: $metadata)
                    Toggle("Playback", isOn: $playback)
                    Toggle("Library", isOn: $library)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add Provider") {
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

// MARK: - Previews

#Preview("ProviderDetailView") {
    let store = MSRUPreviewData.makeProviderStore()
    ProviderDetailView(store: store, providerID: store.orderedProviders[0].id)
        .frame(width: 640, height: 560)
}

#Preview("AddProviderView") {
    AddProviderView(store: MSRUPreviewData.makeProviderStore())
}

