//
//  SceneSection.swift
//  MSRU
//

import Foundation


// MARK: - Scene Root Section

/*
 SceneSection 是 Scene 的语义根路由。

 它属于 Application Architecture，
 不属于 Sidebar UI。

 Sidebar 只是当前用于选择 SceneSection
 的一种平台表现形式。
 */

nonisolated enum SceneSection:
    String,
    Codable,
    CaseIterable,
    Identifiable,
    Hashable,
    Sendable {

    case listenNow
    case browse
    case radio

    case library
    case albums
    case artists

    case addMusic
    case importReview

    case settings


    var id:
        Self {

        self
    }
}
