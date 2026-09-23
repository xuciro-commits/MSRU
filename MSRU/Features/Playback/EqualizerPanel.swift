import SwiftUI
import MusicLibrary
import MusicPlayback

struct EqualizerPanel: View {
    @Bindable var playback: PlaybackController
    @State private var presetName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Equalizer", isOn: Binding(
                get: { playback.equalizer.state.isEnabled },
                set: { playback.setEqualizerEnabled($0) }
            ))
            .font(.headline)

            Menu {
                ForEach(EqualizerPreset.builtIn) { preset in
                    Button(preset.name) { playback.applyEqualizerPreset(preset.id) }
                }
                if !playback.equalizer.state.customPresets.isEmpty {
                    Divider()
                    ForEach(playback.equalizer.state.customPresets) { preset in
                        Button(preset.name) { playback.applyEqualizerPreset(preset.id) }
                    }
                }
            } label: {
                HStack {
                    Text("Preset")
                    Spacer()
                    Text(selectedPresetName)
                    Image(systemName: "chevron.down")
                }
            }

            Divider()

            ScrollView {
                VStack(spacing: 9) {
                    ForEach(EqualizerState.frequencies.indices, id: \.self) { band in
                        HStack(spacing: 9) {
                            Text(frequencyLabel(EqualizerState.frequencies[band]))
                                .monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                            Slider(value: Binding(
                                get: { Double(playback.equalizer.state.gains[band]) },
                                set: { playback.setEqualizerGain(Float($0), band: band) }
                            ), in: -12...12)
                            Text(String(format: "%+.1f dB", playback.equalizer.state.gains[band]))
                                .monospacedDigit()
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
            }

            HStack {
                TextField("New preset name", text: $presetName)
                Button("Save") {
                    playback.saveEqualizerPreset(named: presetName)
                    presetName = ""
                }
                .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let selected = playback.equalizer.state.customPresets.first(where: {
                $0.id == playback.equalizer.state.selectedPresetID
            }) {
                Button("Delete \(selected.name)", role: .destructive) {
                    playback.deleteEqualizerPreset(selected.id)
                }
            }

            Divider()
            Text(playback.equalizerStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
            if playback.equalizer.state.isEnabled,
               playback.equalizer.state.gains.contains(where: { $0 > 0 }) {
                Text("Boost may clip loud recordings; playback volume stays unchanged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
            Picker("Loudness", selection: Binding(
                get: { playback.replayGainSettings.mode },
                set: { playback.setReplayGainMode($0) }
            )) {
                Text("Off").tag(ReplayGainMode.off)
                Text("Track").tag(ReplayGainMode.track)
                Text("Album").tag(ReplayGainMode.album)
            }
            .pickerStyle(.segmented)
            Text("Analysis runs only when requested. Missing results play at original gain.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Analyze Track") { playback.analyzeCurrentLoudness() }
                Button("Analyze Queued Album") { playback.analyzeCurrentLoudness(includeQueuedAlbum: true) }
                if playback.isAnalyzingLoudness {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { playback.cancelLoudnessAnalysis() }
                }
            }
            .disabled(playback.currentItem?.localTrack == nil)
            if let message = playback.loudnessMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 380, height: 650)
    }

    private var selectedPresetName: String {
        guard let id = playback.equalizer.state.selectedPresetID else { return "Custom" }
        return playback.equalizer.presets.first(where: { $0.id == id })?.name ?? "Custom"
    }

    private func frequencyLabel(_ frequency: Float) -> String {
        frequency >= 1_000 ? String(format: "%.0fk", frequency / 1_000) : String(format: "%.0f", frequency)
    }
}

#Preview("Equalizer and Loudness") {
    EqualizerPanel(playback: MSRUPreviewData.makePlaybackController())
}
