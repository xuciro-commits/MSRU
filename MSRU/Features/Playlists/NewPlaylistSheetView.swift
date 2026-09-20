//
//  NewPlaylistSheetView.swift
//  MSRU
//

import SwiftUI

@MainActor
struct NewPlaylistSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var initialTitle: String = ""
    var initialDescription: String = ""
    var onSave: (String, String?) -> Void

    @State private var title: String = ""
    @State private var playlistDescription: String = ""

    init(
        initialTitle: String = "",
        initialDescription: String = "",
        onSave: @escaping (String, String?) -> Void
    ) {
        self.initialTitle = initialTitle
        self.initialDescription = initialDescription
        self.onSave = onSave
        _title = State(initialValue: initialTitle)
        _playlistDescription = State(initialValue: initialDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(LocalizedStringKey("Playlist Name"), text: $title)
                        .textFieldStyle(.roundedBorder)

                    TextField(LocalizedStringKey("Description (Optional)"), text: $playlistDescription, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text(LocalizedStringKey("Details"))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(initialTitle.isEmpty ? LocalizedStringKey("New Playlist") : LocalizedStringKey("Edit Playlist"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Save")) {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let desc = playlistDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed, desc.isEmpty ? nil : desc)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .frame(minWidth: 320, minHeight: 220)
        }
    }
}

// MARK: - Previews

#Preview("New Playlist Sheet") {
    NewPlaylistSheetView(
        initialTitle: "Favorites",
        initialDescription: "Top favorite tracks",
        onSave: { title, desc in
            print("Saved playlist:", title, desc ?? "")
        }
    )
}
