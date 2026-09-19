//
//  SceneNavigation.swift
//  MSRU
//

import Observation


// MARK: - Scene Navigation

/*
 SceneNavigation 属于 Scene Scope。

 每一个 Window / Scene
 都拥有独立 Navigation runtime。

 SceneSection 是语义路由。

 Sidebar、Toolbar、Menu、Command、
 Deep Link 都只是未来可能驱动它的入口。
 */

@MainActor
@Observable
final class SceneNavigation {

    // MARK: - Root

    private(set) var section:
        SceneSection


    // MARK: - Init

    init(
        section:
            SceneSection = .listenNow
    ) {

        self.section =
            section
    }


    // MARK: - Navigate

    func select(
        _ section:
            SceneSection
    ) {

        self.section =
            section
    }


    // MARK: - Reset

    func reset() {

        section =
            .listenNow
    }
}
