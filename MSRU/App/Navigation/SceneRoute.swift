//
//  SceneRoute.swift
//  MSRU
//

import Foundation


// MARK: - Scene Route

/*
 SceneRoute 描述：

 “这个 Scene 应该去哪里”

 它是语义地址，不是 SwiftUI NavigationPath，
 也不是 AppKit ViewController。

 当前真实存在的 destination
 只有 root SceneSection。

 等真实 detail 页面出现以后，
 再扩展新的 typed route。
 */

nonisolated enum SceneRoute:
    Codable,
    Equatable,
    Hashable,
    Sendable {

    case section(
        SceneSection
    )


    // MARK: - Root Section

    var rootSection:
        SceneSection {

        switch self {

        case .section(
            let section
        ):

            section
        }
    }
}
