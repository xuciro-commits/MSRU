//
//  SidebarPaneView.swift
//  MSRU
//

import SwiftUI
import Observation


struct SidebarPaneView:
    View {

    @Bindable
    var scene:
        SceneModel


    var body:
        some View {

        SidebarView(
            selection:
                sidebarSelection
        )
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
    }


    // MARK: - SwiftUI Adapter

    /*
     SwiftUI List selection 使用 Optional。

     SceneNavigation 的语义状态
     始终必须存在一个 root section。

     所以 nil 不进入 Runtime。
     */

    private var sidebarSelection:
        Binding<SceneSection?> {

        Binding(
            get: {

                scene
                    .navigation
                    .section
            },
            set: {
                section in

                guard
                    let section
                else {

                    return
                }


                scene
                    .navigation
                    .select(
                        section
                    )
            }
        )
    }
}
