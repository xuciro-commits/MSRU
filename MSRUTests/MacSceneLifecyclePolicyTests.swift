//
//  MacSceneLifecyclePolicyTests.swift
//  MSRUTests
//

#if os(macOS)

import Testing

@testable import MSRU


struct MacSceneLifecyclePolicyTests {

    @Test
    func applicationTerminationPreservesRestoration() {

        let policy =
            MacSceneLifecyclePolicy()


        #expect(
            policy
                .restorationDisposition(
                    isApplicationTerminating:
                        true
                )
            ==
            .preserve
        )
    }


    @Test
    func explicitSceneCloseRemovesRestoration() {

        let policy =
            MacSceneLifecyclePolicy()


        #expect(
            policy
                .restorationDisposition(
                    isApplicationTerminating:
                        false
                )
            ==
            .remove
        )
    }


    @Test
    func lastWindowTerminationPolicyIsIndependentFromScenePersistence() {

        let policy =
            MacSceneLifecyclePolicy(
                terminatesAfterLastWindowClosed:
                    true
            )


        #expect(
            policy
                .terminatesAfterLastWindowClosed
        )


        /*
         Closing the Window is still an explicit Scene close.

         If the Application is already terminating,
         prepareForTermination() changes the disposition to
         `.preserve`.
         */

        #expect(
            policy
                .restorationDisposition(
                    isApplicationTerminating:
                        false
                )
            ==
            .remove
        )
    }
}

#endif
