//
//  RadioStation.swift
//  MSRU
//

import Foundation

struct RadioStation: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let description: String
    let genre: RadioGenre
    let streamURL: URL
    let homepageURL: URL?
    let artworkURL: URL?
    let country: String
    let language: String
    let codec: String
    let bitrateKbps: Int?
    let isFeatured: Bool

    init(
        id: String,
        name: String,
        description: String,
        genre: RadioGenre,
        streamURL: URL,
        homepageURL: URL? = nil,
        artworkURL: URL? = nil,
        country: String = "Global",
        language: String = "English",
        codec: String = "AAC",
        bitrateKbps: Int? = 128,
        isFeatured: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.genre = genre
        self.streamURL = streamURL
        self.homepageURL = homepageURL
        self.artworkURL = artworkURL
        self.country = country
        self.language = language
        self.codec = codec
        self.bitrateKbps = bitrateKbps
        self.isFeatured = isFeatured
    }
}

extension RadioStation {
    static let defaultStations: [RadioStation] = [
        RadioStation(
            id: "kexp-903",
            name: "KEXP 90.3 FM",
            description: "Listener-powered music radio from Seattle featuring indie rock, alternative, and eclectic curation.",
            genre: .indie,
            streamURL: URL(string: "https://kexp.streamguys1.com/kexp128.aac")!,
            homepageURL: URL(string: "https://kexp.org")!,
            country: "United States",
            language: "English",
            codec: "AAC",
            bitrateKbps: 128,
            isFeatured: true
        ),
        RadioStation(
            id: "somafm-groovesalad",
            name: "SomaFM: Groove Salad",
            description: "A nicely chilled plate of ambient/downtempo beats and grooves. Commercial-free from San Francisco.",
            genre: .electronic,
            streamURL: URL(string: "https://ice1.somafm.com/groovesalad-128-aac")!,
            homepageURL: URL(string: "https://somafm.com/groovesalad/")!,
            country: "United States",
            language: "Instrumental",
            codec: "AAC",
            bitrateKbps: 128,
            isFeatured: true
        ),
        RadioStation(
            id: "somafm-defcon",
            name: "SomaFM: DEF CON Radio",
            description: "Music for hacking, coding and thinking. Chilled electronic soundscapes directly from DEF CON.",
            genre: .electronic,
            streamURL: URL(string: "https://ice1.somafm.com/defcon-128-aac")!,
            homepageURL: URL(string: "https://somafm.com/defcon/")!,
            country: "United States",
            language: "Instrumental",
            codec: "AAC",
            bitrateKbps: 128,
            isFeatured: false
        ),
        RadioStation(
            id: "bbc-radio-1",
            name: "BBC Radio 1",
            description: "The best new pop, dance, hip hop, and chart music from the United Kingdom.",
            genre: .pop,
            streamURL: URL(string: "https://as-hls-ww-live.akamaized.net/pool_904/live/ww/bbc_radio_one/bbc_radio_one.isml/bbc_radio_one-audio=320000.m3u8")!,
            homepageURL: URL(string: "https://www.bbc.co.uk/sounds/play/live:bbc_radio_one")!,
            country: "United Kingdom",
            language: "English",
            codec: "AAC / HLS",
            bitrateKbps: 320,
            isFeatured: true
        ),
        RadioStation(
            id: "wqxr-classical",
            name: "WQXR 105.9 FM",
            description: "New York's premier classical music station broadcasting live masterworks and symphony recordings.",
            genre: .classical,
            streamURL: URL(string: "https://stream.wqxr.org/wqxr")!,
            homepageURL: URL(string: "https://www.wqxr.org")!,
            country: "United States",
            language: "English",
            codec: "MP3",
            bitrateKbps: 128,
            isFeatured: true
        ),
        RadioStation(
            id: "fip-paris",
            name: "FIP Radio",
            description: "Radio France's legendary eclectic station blending jazz, soul, world music, chanson, and electro.",
            genre: .jazz,
            streamURL: URL(string: "https://icecast.radiofrance.fr/fip-midfi.mp3")!,
            homepageURL: URL(string: "https://www.radiofrance.fr/fip")!,
            country: "France",
            language: "French",
            codec: "MP3",
            bitrateKbps: 128,
            isFeatured: false
        ),
        RadioStation(
            id: "jazz24",
            name: "Jazz24",
            description: "24/7 world-class jazz from Seattle, featuring Miles Davis, Coltrane, Ella Fitzgerald, and modern legends.",
            genre: .jazz,
            streamURL: URL(string: "https://live.wostreaming.net/manifest/ppm-jazz24aac-ibc1.m3u8")!,
            homepageURL: URL(string: "https://www.jazz24.org")!,
            country: "United States",
            language: "English",
            codec: "AAC / HLS",
            bitrateKbps: 256,
            isFeatured: false
        ),
        RadioStation(
            id: "ambient-sleeping-pill",
            name: "Ambient Sleeping Pill",
            description: "A continuous stream of peaceful ambient music designed for deep relaxation, contemplation, and sleep.",
            genre: .ambient,
            streamURL: URL(string: "https://sl128.drn.cx/")!,
            homepageURL: URL(string: "https://ambientsleepingpill.com")!,
            country: "Global",
            language: "Instrumental",
            codec: "MP3",
            bitrateKbps: 128,
            isFeatured: false
        ),
        RadioStation(
            id: "somafm-lush",
            name: "SomaFM: Lush",
            description: "Sensuous and mellow vocal-driven chillout, mostly female vocals with rich electronica textures.",
            genre: .electronic,
            streamURL: URL(string: "https://ice1.somafm.com/lush-128-aac")!,
            homepageURL: URL(string: "https://somafm.com/lush/")!,
            country: "United States",
            language: "English",
            codec: "AAC",
            bitrateKbps: 128,
            isFeatured: false
        ),
        RadioStation(
            id: "swiss-classic",
            name: "Radio Swiss Classic",
            description: "Serene classical music selections from the Swiss Broadcasting Corporation with minimal interruption.",
            genre: .classical,
            streamURL: URL(string: "https://stream.srg-ssr.ch/m/rsc_de/aacp_96")!,
            homepageURL: URL(string: "https://www.radioswissclassic.ch")!,
            country: "Switzerland",
            language: "German",
            codec: "AAC",
            bitrateKbps: 96,
            isFeatured: false
        )
    ]
}
