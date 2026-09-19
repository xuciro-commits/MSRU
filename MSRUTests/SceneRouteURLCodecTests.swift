//
//  SceneRouteURLCodecTests.swift
//  MSRUTests
//

import Foundation
import Testing

@testable import MSRU


struct SceneRouteURLCodecTests {

    private let codec =
        SceneRouteURLCodec(
            scheme:
                "msru"
        )


    @Test
    func allSectionsSupportURLRoundTrip()
        throws {

        for section
        in SceneSection.allCases {

            let route =
                SceneRoute.section(
                    section
                )


            let url =
                try #require(
                    codec
                        .encode(
                            route
                        )
                )


            let decoded =
                codec
                    .decode(
                        url
                    )


            #expect(
                decoded
                ==
                route
            )
        }
    }


    @Test
    func canonicalBrowseURLDecodes() throws {

        let url =
            try #require(
                URL(
                    string:
                        "msru://section/browse"
                )
            )


        #expect(
            codec
                .decode(
                    url
                )
            ==
            .section(
                .browse
            )
        )
    }


    @Test
    func wrongSchemeIsRejected() throws {

        let url =
            try #require(
                URL(
                    string:
                        "other://section/browse"
                )
            )


        #expect(
            codec
                .decode(
                    url
                )
            ==
            nil
        )
    }


    @Test
    func unknownSectionIsRejected() throws {

        let url =
            try #require(
                URL(
                    string:
                        "msru://section/does-not-exist"
                )
            )


        #expect(
            codec
                .decode(
                    url
                )
            ==
            nil
        )
    }


    @Test
    func unknownRouteKindIsRejected() throws {

        let url =
            try #require(
                URL(
                    string:
                        "msru://unknown/browse"
                )
            )


        #expect(
            codec
                .decode(
                    url
                )
            ==
            nil
        )
    }
}
