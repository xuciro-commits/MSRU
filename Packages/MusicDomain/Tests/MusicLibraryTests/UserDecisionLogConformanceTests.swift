import Foundation
import GRDB
import Testing
@testable import MusicLibrary

/// The user decision log conforms to kernel contract v1alpha1 K4. `Vectors/` is a
/// pinned copy of the platform repository's `contract/vectors`; refresh it when
/// the contract version changes, never edit it here.
@Suite("User decision log conforms to K4")
struct UserDecisionLogConformanceTests {
    struct VectorFile: Decodable {
        let contract: String
        let vectors: [Vector]
    }

    struct Vector: Decodable {
        struct Given: Decodable {
            struct Fact: Decodable { let tenantId, factId: String }
            let schemas: [DecisionSchema]
            let facts: [Fact]?
        }
        struct Step: Decodable {
            struct Expect: Decodable {
                struct Accepted: Decodable {
                    let validTime: Date
                    let recordedTime: Date
                    let sameAs: Int?
                }
                let accepted: Accepted?
                let error: String?
            }
            let submit: DecisionSubmission
            let at: Date
            let expect: Expect
        }
        let id: String
        let given: Given
        let steps: [Step]
        let expectLog: [String: Int]?
    }

    @Test func k4Vectors() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Vectors/k4-change-record.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(VectorFile.self, from: Data(contentsOf: url))
        #expect(file.contract == "v1alpha1")
        for vector in file.vectors {
            let queue = try DatabaseQueue()
            try AppDatabase(dbWriter: queue).migrator.migrate(queue)
            let facts = Set((vector.given.facts ?? []).map { [$0.tenantId, $0.factId] })
            var changeIDs: [Int: String] = [:]
            for (index, step) in vector.steps.enumerated() {
                let label = Comment(rawValue: "\(vector.id) step \(index)")
                var submission = step.submit
                if submission.causationId.hasPrefix("$step:"), let n = Int(submission.causationId.dropFirst(6)) {
                    submission.causationId = changeIDs[n] ?? ""
                }
                do {
                    let record = try queue.write { db in
                        try UserDecisionLog.submit(submission, knownSchemas: Set(vector.given.schemas), at: step.at,
                                                   knownFact: { facts.contains([$0, $1]) }, in: db)
                    }
                    changeIDs[index] = record.changeId
                    let expected = try #require(step.expect.accepted, label)
                    #expect(record.validTime == expected.validTime, label)
                    #expect(record.recordedTime == expected.recordedTime, label)
                    if let original = expected.sameAs {
                        #expect(record.changeId == changeIDs[original], label)
                    }
                } catch let error as DecisionError {
                    #expect(step.expect.error == error.rawValue, label)
                }
            }
            for (tenant, count) in vector.expectLog ?? [:] {
                let records = try queue.read { try UserDecisionLog.records(tenant: tenant, in: $0) }
                #expect(records.count == count, Comment(rawValue: "\(vector.id) log \(tenant)"))
            }
        }
    }
}
