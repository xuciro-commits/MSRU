import AppIntents

nonisolated enum MusicIntentLibrarySearch {
    static func exactTrack(title: String, artist: String?, in tracks: [LocalTrack]) -> LocalTrack? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }
        var match: LocalTrack?
        for track in tracks {
            guard track.title.localizedCaseInsensitiveCompare(cleanTitle) == .orderedSame else { continue }
            if let cleanArtist, !cleanArtist.isEmpty,
               track.artist.localizedCaseInsensitiveCompare(cleanArtist) != .orderedSame { continue }
            if match != nil { return nil }
            match = track
        }
        return match
    }

    static func results(for query: String, in tracks: [LocalTrack], limit: Int = 10) -> [String] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return tracks.lazy
            .filter { $0.title.localizedCaseInsensitiveContains(needle) || $0.artist.localizedCaseInsensitiveContains(needle) }
            .prefix(max(0, limit))
            .map { "\($0.title) — \($0.artist)" }
    }
}

@MainActor
struct PlayTrackIntent: @preconcurrency AppIntent {
    static let title: LocalizedStringResource = "Play Song"
    static let description = IntentDescription("Play a song from the local music library.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Song Title") var songTitle: String
    @Parameter(title: "Artist") var artist: String?
    @AppDependency private var application: ApplicationModel

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        await application.localLibrary.loadIfNeeded()
        guard let track = try? await application.localLibrary.findUniqueTrack(
            title: songTitle, artist: artist
        ) else {
            return .result(dialog: "No unique local song matched. Try including the artist.")
        }
        application.playback.play(track)
        return .result(dialog: "Playing \(track.title).")
    }
}

@MainActor
struct SearchMusicIntent: @preconcurrency AppIntent {
    static let title: LocalizedStringResource = "Search Music"
    static let description = IntentDescription("Find songs in the local music library.")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Search") var query: String
    @AppDependency private var application: ApplicationModel

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await application.localLibrary.loadIfNeeded()
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return .result(value: "Enter a song or artist name.") }
        let tracks = (try? await application.localLibrary.searchTracks(needle)) ?? []
        let matches = tracks.map { "\($0.title) — \($0.artist)" }
        return .result(value: matches.isEmpty ? "No matching songs." : matches.joined(separator: "\n"))
    }
}

nonisolated struct MusicAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PlayTrackIntent(), phrases: ["Play a song in \(.applicationName)"], shortTitle: "Play Song", systemImageName: "play.fill")
        AppShortcut(intent: SearchMusicIntent(), phrases: ["Search music in \(.applicationName)"], shortTitle: "Search Music", systemImageName: "magnifyingglass")
    }
}
