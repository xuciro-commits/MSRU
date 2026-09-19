//
//  ApplicationCommandSource.swift
//  MSRU
//


// MARK: - Application Command Source

/*
 ApplicationCommandSource 描述：

 “如何把某种外部 representation
  转换成 ApplicationCommand”


 Source 只负责 representation translation。

 它不负责：

 - command execution
 - runtime readiness
 - buffering
 - Scene creation
 - navigation
 - restoration
 - platform lifecycle


 Pipeline:

 External Representation
          │
          ▼
 ApplicationCommandSource
          │
          ▼
 ApplicationCommand


 Future sources 可以包括：

 - URL
 - App Intent
 - Spotlight activity
 - Handoff activity
 - Notification response
 - automation payload
 - plugin payload


 Source 与 Runtime 完全解耦。
 */

protocol ApplicationCommandSource {

    associatedtype Input


    func command(
        from input:
            Input
    ) -> ApplicationCommand?
}
