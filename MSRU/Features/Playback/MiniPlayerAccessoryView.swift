import SwiftUI
import Observation


struct MiniPlayerAccessoryView:
    View {

    @Bindable var playback:
        PlaybackController

    let onToggleQueue:
        () -> Void


    var body: some View {

        MiniPlayerBar(
            playback:
                playback,
            onToggleQueue:
                onToggleQueue
        )
        /*
         这是 Capsule 外部 breathing room。

         不参与 MiniPlayer 自己的内部宽度计算。
         */
        .padding(
            .horizontal,
            20
        )
        .padding(
            .vertical,
            8
        )
    }
}


#Preview {

    MiniPlayerAccessoryView(
        playback:
            MSRUPreviewData.makePlaybackController(),
        onToggleQueue: {}
    )
}
