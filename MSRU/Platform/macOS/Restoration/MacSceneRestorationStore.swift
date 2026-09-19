//
//  MacSceneRestorationStore.swift
//  MSRU
//

#if os(macOS)

import Foundation


// MARK: - macOS Scene Restoration Store

/*
 macOS semantic Scene state。

 Window geometry 不存这里。

 Geometry 交给 AppKit
 NSWindow frame autosave。

 这里仅保存：

 SceneRestorationSnapshot
 */

@MainActor
final class MacSceneRestorationStore:
    SceneRestorationStore {

    // MARK: - Storage

    private let defaults:
        UserDefaults


    private let storageKey =
        "MSRU.SceneRestoration.Snapshots.v1"


    // MARK: - Init

    init(
        defaults:
            UserDefaults = .standard
    ) {

        self.defaults =
            defaults
    }


    // MARK: - Load

    func loadSnapshots()
        -> [SceneRestorationSnapshot] {

        guard
            let data =
                defaults.data(
                    forKey:
                        storageKey
                )
        else {

            return []
        }


        guard
            let snapshots =
                try? JSONDecoder()
                    .decode(
                        [SceneRestorationSnapshot]
                            .self,
                        from:
                            data
                    )
        else {

            /*
             Corrupt restoration data
             不允许阻止 App 启动。
             */

            return []
        }


        return
            snapshots
    }


    // MARK: - Save

    func save(
        _ snapshot:
            SceneRestorationSnapshot
    ) {

        var snapshots =
            loadSnapshots()


        if let index =
            snapshots
                .firstIndex(
                    where: {
                        $0.sceneID
                        ==
                        snapshot.sceneID
                    }
                ) {

            snapshots[
                index
            ] =
                snapshot

        } else {

            snapshots.append(
                snapshot
            )
        }


        guard
            let data =
                try? JSONEncoder()
                    .encode(
                        snapshots
                    )
        else {

            return
        }


        defaults.set(
            data,
            forKey:
                storageKey
        )
    }


    // MARK: - Remove

    func remove(
        sceneID:
            SceneID
    ) {

        var snapshots =
            loadSnapshots()


        snapshots.removeAll {
            snapshot in

            snapshot.sceneID
            ==
            sceneID
        }


        guard
            !snapshots.isEmpty
        else {

            defaults.removeObject(
                forKey:
                    storageKey
            )

            return
        }


        guard
            let data =
                try? JSONEncoder()
                    .encode(
                        snapshots
                    )
        else {

            return
        }


        defaults.set(
            data,
            forKey:
                storageKey
        )
    }
}

#endif
