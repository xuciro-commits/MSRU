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
                Text("Add Provider").font(.title2.bold())
                Text("Register a remote HTTP/JSON provider configuration.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Form {
                Section("Provider") {
                    TextField("Name", text: $name)
                    TextField("Provider or manifest URL", text: $endpoint)
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

#Preview("AddProviderView") {
    AddProviderView(store: MSRUPreviewData.makeProviderStore())
}
