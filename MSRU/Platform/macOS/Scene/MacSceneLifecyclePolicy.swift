//
//  MacSceneLifecyclePolicy.swift
//  MSRU
//

#if os(macOS)


// MARK: - Restoration Disposition

nonisolated enum MacSceneRestorationDisposition:
    Equatable,
    Sendable {

    /// The Scene still represents application state that should
    /// be restored during the next launch.
    case preserve

    /// The user explicitly closed this Scene while the
    /// application continues running.
    case remove
}


// MARK: - Scene Lifecycle Policy

/// Distinguishes:
///
/// - closing one Scene
/// - closing the final Scene
/// - terminating the whole application
///
/// Window lifecycle is not equivalent to Scene persistence
/// lifecycle.
nonisolated struct MacSceneLifecyclePolicy:
    Equatable,
    Sendable {

    let terminatesAfterLastWindowClosed:
        Bool


    init(
        terminatesAfterLastWindowClosed:
            Bool = true
    ) {

        self.terminatesAfterLastWindowClosed =
            terminatesAfterLastWindowClosed
    }


    func restorationDisposition(
        isApplicationTerminating:
            Bool
    ) -> MacSceneRestorationDisposition {

        /*
         Application termination preserves every currently
         living Scene.

         Explicit Window / Scene close is different: it means
         that Scene has been discarded and must not be restored.

         The number of remaining windows does not change that
         semantic distinction.
         */

        isApplicationTerminating
        ?
        .preserve
        :
        .remove
    }
}

#endif
