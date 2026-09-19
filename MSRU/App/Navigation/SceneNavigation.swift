//
//  SceneNavigation.swift
//  MSRU
//

import Observation


// MARK: - Scene Navigation

/*
 SceneNavigation 是 Scene-owned
 navigation runtime。

 SceneRoute 是输入。

 SceneSection 是当前真实存在的
 root navigation state。

 SwiftUI / AppKit 不进入这一层。
 */

@MainActor
@Observable
final class SceneNavigation {

    // MARK: - State

    private(set) var section:
        SceneSection


    // MARK: - Current Route

    var route:
        SceneRoute {

        .section(
            section
        )
    }


    // MARK: - Init

    init(
        section:
            SceneSection = .listenNow
    ) {

        self.section =
            section
    }


    // MARK: - Navigate

    func navigate(
        to route:
            SceneRoute
    ) {

        switch route {

        case .section(
            let section
        ):

            self.section =
                section
        }
    }


    // MARK: - Select

    /*
     保留 section-level primitive。

     Scene 外部的新调用入口
     应优先通过 SceneModel.send(_:)。

     这也让当前已有测试和
     restoration code 不必被一次性打碎。
     */

    func select(
        _ section:
            SceneSection
    ) {

        navigate(
            to:
                .section(
                    section
                )
        )
    }


    // MARK: - Reset

    func reset() {

        navigate(
            to:
                .section(
                    .listenNow
                )
        )
    }
}
