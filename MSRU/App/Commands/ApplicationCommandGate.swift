//
//  ApplicationCommandGate.swift
//  MSRU
//


// MARK: - Application Command Gate

/*
 ApplicationCommandGate 解决：

     Command delivery lifecycle
     !=
     Runtime lifecycle


 External systems 可能在 runtime ready 之前发送 command：

 - URL
 - App Intent
 - Handoff
 - Spotlight
 - system restoration
 - automation
 - future plugin host


 Gate 是纯 application infrastructure。

 它不知道：

 - macOS
 - iOS
 - Window
 - SwiftUI
 - AppKit
 - Feature
 - 任何业务


 Pipeline:

 ApplicationCommandCenter
          │
          ▼
 ApplicationCommandGate
          │
          ├── suspended
          │      └── FIFO buffer
          │
          └── active
                 │
                 ▼
       downstream handler
 */

@MainActor
final class ApplicationCommandGate:
    ApplicationCommandHandler {

    // MARK: - State

    private enum State {

        case suspended
        case active
    }


    private var state:
        State


    // MARK: - Downstream

    private let downstream:
        any ApplicationCommandHandler


    // MARK: - Buffer

    private var pendingCommands:
        [ApplicationCommand] = []


    // MARK: - Init

    /*
     默认 suspended。

     Composition root 必须显式决定
     runtime 什么时候真正 ready。
     */

    init(
        downstream:
            any ApplicationCommandHandler,
        startsActive:
            Bool = false
    ) {

        self.downstream =
            downstream


        self.state =
            startsActive
            ? .active
            : .suspended
    }


    // MARK: - State Projection

    var isActive:
        Bool {

        switch state {

        case .active:

            true


        case .suspended:

            false
        }
    }


    var pendingCount:
        Int {

        pendingCommands
            .count
    }


    // MARK: - Handle

    func handle(
        _ command:
            ApplicationCommand
    ) -> ApplicationCommandResult {

        guard
            isActive
        else {

            pendingCommands
                .append(
                    command
                )

            return
                .deferred
        }


        return
            downstream
                .handle(
                    command
                )
    }


    // MARK: - Activate

    /*
     激活 gate，并按照接收顺序 flush。

     activate() 是幂等的。

     第二次 activate 不会重新执行
     已经 flush 的 command。
     */

    @discardableResult
    func activate()
        -> [ApplicationCommandResult] {

        guard
            !isActive
        else {

            return []
        }


        state =
            .active


        let commands =
            pendingCommands


        pendingCommands
            .removeAll(
                keepingCapacity:
                    true
            )


        return
            commands
                .map {
                    downstream
                        .handle(
                            $0
                        )
                }
    }


    // MARK: - Suspend

    /*
     Suspend 不影响已经执行的 command。

     之后到达的新 command
     会重新进入 buffer。

     这允许未来：

     - scene runtime replacement
     - platform lifecycle interruption
     - test-controlled runtime phases
     */

    func suspend() {

        state =
            .suspended
    }
}
