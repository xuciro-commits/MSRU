//
//  TrackCorrectionsSection.swift
//  MSRU
//
//  User corrections of a track's displayed title, artist and album. Each save is
//  a recorded decision with principal and time; file tags are never changed.
//

import SwiftUI
import MusicLibrary

struct TrackCorrectionsSection: View {
    let track: LocalTrack
    let store: LocalLibraryStore?
    @State var history = MetadataCorrections.History()
    @State private var isEditing = false
    @State private var errorMessage: String?

    /// Fields whose latest decision is a correction (not a restore).
    private var correctedFields: [MetadataCorrections.Field] {
        MetadataCorrections.Field.allCases.filter { field in
            history.corrections.last { $0.field == field }?.value != nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Corrections")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Edit…") { isEditing = true }
                    .controlSize(.small)
                    .disabled(store == nil || !track.fileURL.isFileURL)
            }

            if history.corrections.isEmpty {
                Text("No corrections. File tags are never changed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(history.corrections.enumerated().reversed()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.value.map { "\(entry.field.label): \($0)" } ?? "\(entry.field.label): restored from file tags")
                            .font(.caption)
                            .lineLimit(2)
                        Text("\(entry.principal) · \(entry.recordedTime.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                ForEach(correctedFields, id: \.self) { field in
                    Button("Restore \(field.label) from Tags") { save([field: nil]) }
                        .controlSize(.small)
                        .disabled(store == nil)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task(id: track.id) { await reload() }
        .sheet(isPresented: $isEditing) {
            CorrectionEditor(track: track) { changes in save(changes) }
        }
    }

    private func reload() async {
        guard let store else { return }
        history = (try? await store.corrections(of: track)) ?? .init()
    }

    private func save(_ changes: [MetadataCorrections.Field: String?]) {
        guard let store, !changes.isEmpty else { return }
        Task {
            do {
                // Each correction names the revision this section showed (K4 C12).
                var revision = history.revision
                for field in MetadataCorrections.Field.allCases {
                    if let value = changes[field] {
                        revision = try await store.correct(track, field: field, value: value, expectedRevision: revision)
                    }
                }
                errorMessage = nil
            } catch DecisionError.conflict {
                errorMessage = "Changed elsewhere. The latest corrections are shown."
            } catch {
                errorMessage = "Could not save the correction."
            }
            await reload()
        }
    }
}

private struct CorrectionEditor: View {
    let track: LocalTrack
    let onSave: ([MetadataCorrections.Field: String?]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var artist: String
    @State private var album: String

    init(track: LocalTrack, onSave: @escaping ([MetadataCorrections.Field: String?]) -> Void) {
        self.track = track
        self.onSave = onSave
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
        _album = State(initialValue: track.album ?? "")
    }

    /// Changed, non-empty fields only; clearing a field is not a correction.
    private var changes: [MetadataCorrections.Field: String?] {
        let edited: [(MetadataCorrections.Field, String, String)] = [
            (.title, title, track.title), (.artist, artist, track.artist), (.album, album, track.album ?? "")
        ]
        return Dictionary(uniqueKeysWithValues: edited.compactMap { field, new, old in
            let value = new.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty || value == old ? nil : (field, value)
        })
    }

    var body: some View {
        Form {
            TextField("Title", text: $title)
            TextField("Artist", text: $artist)
            TextField("Album", text: $album)
            Text("Corrections change what MSRU shows. File tags stay unchanged.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(minWidth: 360)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(changes)
                    dismiss()
                }
                .disabled(changes.isEmpty)
            }
        }
    }
}

private extension MetadataCorrections.Field {
    var label: String {
        switch self {
        case .title: "Title"
        case .artist: "Artist"
        case .album: "Album"
        }
    }
}

#Preview("Corrections") {
    TrackCorrectionsSection(
        track: MSRUPreviewData.localTracks[0],
        store: nil,
        history: .init(corrections: [
            .init(field: .title, value: "Corrected Title", principal: UserDecisionLog.localPrincipal,
                  recordedTime: Date(timeIntervalSince1970: 1_767_225_600)),
            .init(field: .title, value: nil, principal: UserDecisionLog.localPrincipal,
                  recordedTime: Date(timeIntervalSince1970: 1_767_229_200))
        ], revision: 2)
    )
    .padding()
    .frame(width: 320)
}

#Preview("Correction Editor") {
    CorrectionEditor(track: MSRUPreviewData.localTracks[0]) { _ in }
}
