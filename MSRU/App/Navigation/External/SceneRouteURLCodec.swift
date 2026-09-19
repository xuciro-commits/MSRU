//
//  SceneRouteURLCodec.swift
//  MSRU
//

import Foundation


// MARK: - Scene Route URL Codec

/*
 External URL 与 SceneRoute 之间的纯转换。

 Codec 不知道：

 - Window
 - SceneModel
 - AppDelegate
 - SwiftUI
 - AppKit

 当前 canonical URL：

 msru://section/listenNow
 msru://section/browse
 msru://section/radio
 msru://section/library
 msru://section/addMusic
 msru://section/settings
 */

nonisolated struct SceneRouteURLCodec:
    Sendable {

    // MARK: - Configuration

    let scheme:
        String


    // MARK: - Init

    init(
        scheme:
            String
    ) {

        self.scheme =
            scheme
                .lowercased()
    }


    // MARK: - Decode

    func decode(
        _ url:
            URL
    ) -> SceneRoute? {

        guard
            url.scheme?
                .lowercased()
            ==
            scheme
        else {

            return nil
        }


        guard
            url.host?
                .lowercased()
            ==
            "section"
        else {

            return nil
        }


        let pathComponents =
            url
                .path
                .split(
                    separator:
                        "/"
                )


        guard
            pathComponents.count
            ==
            1
        else {

            return nil
        }


        let rawValue =
            String(
                pathComponents[0]
            )


        guard
            let section =
                SceneSection(
                    rawValue:
                        rawValue
                )
        else {

            return nil
        }


        return
            .section(
                section
            )
    }


    // MARK: - Encode

    func encode(
        _ route:
            SceneRoute
    ) -> URL? {

        var components =
            URLComponents()


        components.scheme =
            scheme


        switch route {

        case .section(
            let section
        ):

            components.host =
                "section"


            components.path =
                "/"
                +
                section.rawValue
        }


        return
            components.url
    }
}
