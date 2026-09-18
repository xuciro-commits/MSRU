//
//  PlaybackRequest.swift
//  MSRU
//

import Foundation


enum PlaybackQuality:
    String,
    Sendable {

    case automatic
    case low
    case standard
    case high
    case lossless
}


struct PlaybackRequest:
    Sendable {

    enum Source:
        String,
        Sendable {

        case local
        case openverse
    }


    let itemID:
        String

    let source:
        Source

    let preferredQuality:
        PlaybackQuality

    let localFileURL:
        URL?

    let remoteURL:
        URL?

    let providerHint:
        PlaybackProviderID?


    // MARK: - Unified Init

    init(
        itemID:
            String,
        source:
            Source,
        preferredQuality:
            PlaybackQuality = .automatic,
        localFileURL:
            URL? = nil,
        remoteURL:
            URL? = nil,
        providerHint:
            PlaybackProviderID? = nil
    ) {

        self.itemID =
            itemID

        self.source =
            source

        self.preferredQuality =
            preferredQuality

        self.localFileURL =
            localFileURL

        self.remoteURL =
            remoteURL

        self.providerHint =
            providerHint
    }


    // MARK: - Legacy Local UUID Compatibility

    /*
     兼容旧 LocalTrack API：

     PlaybackRequest(
         trackID: UUID,
         ...
     )
     */
    init(
        trackID:
            UUID,
        preferredQuality:
            PlaybackQuality = .automatic,
        localFileURL:
            URL?
    ) {

        self.init(
            itemID:
                "local:\(trackID.uuidString)",
            source:
                .local,
            preferredQuality:
                preferredQuality,
            localFileURL:
                localFileURL,
            remoteURL:
                nil,
            providerHint:
                .local
        )
    }


    // MARK: - String ID Compatibility

    /*
     新 PlaybackItem 使用 String identity：

         local:<uuid>
         openverse:<id>

     部分过渡代码仍可能写：

         PlaybackRequest(
             trackID: item.id,
             ...
         )

     因此这里允许 String，
     让迁移期间旧代码继续编译。
     */
    init(
        trackID:
            String,
        preferredQuality:
            PlaybackQuality = .automatic,
        localFileURL:
            URL?
    ) {

        let normalizedID:

            String


        if trackID.hasPrefix(
            "local:"
        ) {

            normalizedID =
                trackID

        } else {

            normalizedID =
                "local:\(trackID)"
        }


        self.init(
            itemID:
                normalizedID,
            source:
                .local,
            preferredQuality:
                preferredQuality,
            localFileURL:
                localFileURL,
            remoteURL:
                nil,
            providerHint:
                .local
        )
    }
}
