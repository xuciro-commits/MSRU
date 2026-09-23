#if os(macOS)
import SwiftUI

struct AudioOutputMenu: View {
    @Bindable var playback: PlaybackController
    var iconColor: Color = .secondary

    var body: some View {
        Menu {
            Button {
                playback.selectOutputDevice(nil)
            } label: {
                selectionLabel("System Default", selected: playback.audioOutput.selectedUID == nil)
            }
            if !playback.audioOutput.devices.isEmpty { Divider() }
            ForEach(playback.audioOutput.devices) { device in
                Button {
                    playback.selectOutputDevice(device.uid)
                } label: {
                    selectionLabel(device.name, selected: playback.audioOutput.selectedUID == device.uid)
                }
            }
            Divider()
            Toggle("Exclusive access", isOn: Binding(
                get: { playback.audioOutput.exclusiveRequested },
                set: { playback.setExclusiveOutput($0) }
            ))
            .disabled(playback.audioOutput.selectedUID == nil)
            Divider()
            Text(playback.outputFormatSummary)
            if let note = playback.audioOutput.errorMessage { Text(note) }
            Text("Bit-perfect output is unverified")
        } label: {
            Image(systemName: "hifispeaker")
                .font(.system(size: 13))
                .foregroundStyle(iconColor)
                .frame(width: 20, height: 20)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Audio output: \(playback.audioOutput.displayName)")
    }

    private func selectionLabel(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
            if selected { Image(systemName: "checkmark") }
        }
    }
}

#Preview("Audio Output") {
    AudioOutputMenu(playback: MSRUPreviewData.makePlaybackController())
        .padding()
}
#endif
