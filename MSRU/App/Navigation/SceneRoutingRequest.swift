//
//  SceneRoutingRequest.swift
//  MSRU
//


// MARK: - Scene Routing Request

/*
 Route:

 “去哪里”

 Target:

 “在哪个 Scene 中打开”
 */

nonisolated struct SceneRoutingRequest:
    Equatable,
    Sendable {

    let route:
        SceneRoute


    let target:
        SceneRoutingTarget


    init(
        route:
            SceneRoute,
        target:
            SceneRoutingTarget = .activeOrNew
    ) {

        self.route =
            route


        self.target =
            target
    }
}
