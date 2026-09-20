//
//  AddStationSheetView.swift
//  MSRU
//

import SwiftUI

struct AddStationSheetView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var streamURLString: String = ""
    @State private var genre: RadioGenre = .classical
    @State private var country: String = "Global"
    @State private var descriptionText: String = ""
    @State private var errorMessage: String? = nil

    let onSave: (RadioStation) -> Void

    private var isValidURL: Bool {
        guard let url = URL(string: streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        return true
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isValidURL
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Station Details") {
                    TextField("Station Name", text: $name, prompt: Text("e.g. My Favorite Station"))

                    TextField("Stream URL", text: $streamURLString, prompt: Text("https://example.com/stream.mp3"))
                        #if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        #endif

                    if !streamURLString.isEmpty && !isValidURL {
                        Text("Please enter a valid HTTP or HTTPS stream URL.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Picker("Genre", selection: $genre) {
                        ForEach(RadioGenre.allCases.filter { $0 != .all }) { item in
                            Text(LocalizedStringKey(item.rawValue)).tag(item)
                        }
                    }

                    TextField("Country/Region", text: $country, prompt: Text("e.g. Global, China, USA"))
                    TextField("Description (Optional)", text: $descriptionText, prompt: Text("Optional notes or tagline"))
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Custom Station")
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 340)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard canSave,
              let url = URL(string: streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Invalid stream URL or missing station name."
            return
        }

        let newStation = RadioStation(
            id: "custom-\(UUID().uuidString.prefix(8).lowercased())",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "User-added custom stream."
                : descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            genre: genre,
            streamURL: url,
            country: country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Global"
                : country.trimmingCharacters(in: .whitespacesAndNewlines),
            isFeatured: false,
            isCustom: true
        )

        onSave(newStation)
        dismiss()
    }
}

#Preview("Add Station Sheet") {
    AddStationSheetView(onSave: { _ in })
}
