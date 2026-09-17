//
//  PlaybackResource.swift
//  MSRU
//

import Foundation


enum PlaybackTransport:
    Sendable {

    /*
     AVPlayer 可以直接消费的资源。

     Local file 与普通 remote URL
     都属于这一类。
     */

    case avPlayerURL(
        URL
    )


    /*
     Provider 自己负责播放的资源。

     例如未来：

     Apple Music
     MusicKit

     不需要把它伪装成普通 HTTP URL。
     */

    case providerNative(
        providerID:
            PlaybackProviderID,
        itemID:
            String
    )
}


struct PlaybackResource:
    Sendable {

    let providerID:
        PlaybackProviderID

    let transport:
        PlaybackTransport

    let quality:
        PlaybackQuality


    /*
     网络 Provider 返回的 URL
     以后很可能存在时效。

     Local 为 nil。
     */

    let expiresAt:
        Date?


    init(
        providerID:
            PlaybackProviderID,
        transport:
            PlaybackTransport,
        quality:
            PlaybackQuality,
        expiresAt:
            Date? = nil
    ) {

        self.providerID =
            providerID

        self.transport =
            transport

        self.quality =
            quality

        self.expiresAt =
            expiresAt
    }
}
