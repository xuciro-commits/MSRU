#if os(macOS)
import Foundation
import AppFoundation

/// Semantic restoration only. AppKit owns window geometry.
/// Unknown/malformed records survive mutations; supported records restore independently.
@MainActor
final class MacSceneRestorationStore: SceneRestorationStore {
    private let defaults: UserDefaults
    private let storageKey = "MSRU.SceneRestoration.Snapshots.v1"
    private var quarantineKey: String { storageKey + ".quarantine" }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSnapshots() -> [SceneRestorationSnapshot] {
        var result: [SceneRestorationSnapshot] = []
        for record in records(preservingCorruptDocument: false) {
            guard let snapshot = supportedSnapshot(record) else { continue }
            if let index = result.firstIndex(where: { $0.sceneID == snapshot.sceneID }) {
                result[index] = snapshot
            } else {
                result.append(snapshot)
            }
        }
        return result
    }

    func save(_ snapshot: SceneRestorationSnapshot) {
        guard snapshot.isSupported,
              let data = try? JSONEncoder().encode(snapshot),
              let record = try? JSONSerialization.jsonObject(with: data) else { return }
        var values = records(preservingCorruptDocument: true)
        // Replace only records whose schema this version understands.
        values.removeAll { supportedSnapshot($0)?.sceneID == snapshot.sceneID }
        values.append(record)
        write(values)
    }

    func remove(sceneID: SceneID) {
        var values = records(preservingCorruptDocument: true)
        values.removeAll { supportedSnapshot($0)?.sceneID == sceneID }
        write(values)
    }

    private func supportedSnapshot(_ record: Any) -> SceneRestorationSnapshot? {
        guard let data = try? JSONSerialization.data(withJSONObject: record, options: .fragmentsAllowed),
              let snapshot = try? JSONDecoder().decode(SceneRestorationSnapshot.self, from: data),
              snapshot.isSupported else { return nil }
        return snapshot
    }

    private func records(preservingCorruptDocument: Bool) -> [Any] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        if let records = (try? JSONSerialization.jsonObject(with: data)) as? [Any] {
            return records
        }
        // A broken top-level document cannot be merged. Preserve its exact bytes
        // before a save/remove replaces it, with no duplicate backups on repeat reads.
        if preservingCorruptDocument {
            var quarantined = defaults.array(forKey: quarantineKey) as? [Data] ?? []
            if !quarantined.contains(data) {
                quarantined.append(data)
                defaults.set(quarantined, forKey: quarantineKey)
            }
        }
        return []
    }

    private func write(_ records: [Any]) {
        if records.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else if let data = try? JSONSerialization.data(withJSONObject: records, options: .sortedKeys) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
#endif
