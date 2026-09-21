//
//  SecurityScopePolicyTests.swift
//  MSRUTests
//
//  Created for SecurityScopePolicy unit tests.
//

import Testing
import Foundation
@testable import MSRU

@Suite("Security Scope Policy Tests")
struct SecurityScopePolicyTests {

    @Test("Sandbox detection produces valid options")
    func testSandboxDetectionProducesValidOptions() {
        let isSandboxed = SecurityScopePolicy.isSandboxed
        if isSandboxed {
            #expect(SecurityScopePolicy.bookmarkCreationOptions == .withSecurityScope)
            #expect(SecurityScopePolicy.bookmarkResolutionOptions == .withSecurityScope)
        } else {
            #expect(SecurityScopePolicy.bookmarkCreationOptions == [])
            #expect(SecurityScopePolicy.bookmarkResolutionOptions == [])
        }
    }

    @Test("Local volume detection correctly identifies root and temp filesystem")
    func testLocalVolumeDetection() {
        let rootURL = URL(fileURLWithPath: "/")
        #expect(SecurityScopePolicy.isLocalVolume(rootURL) == true)

        let tempURL = FileManager.default.temporaryDirectory
        #expect(SecurityScopePolicy.isLocalVolume(tempURL) == true)
    }

    @Test("Coordinate access executes synchronous block cleanly")
    func testCoordinateAccessSync() {
        let tempURL = FileManager.default.temporaryDirectory
        let result = SecurityScopePolicy.coordinateAccess(to: tempURL) { url in
            url.path
        }
        #expect(!result.isEmpty)
    }

    @Test("Coordinate access executes asynchronous block cleanly")
    func testCoordinateAccessAsync() async throws {
        let tempURL = FileManager.default.temporaryDirectory
        let result = try await SecurityScopePolicy.coordinateAccessAsync(to: tempURL) { url in
            try await Task.sleep(nanoseconds: 1_000_000)
            return url.lastPathComponent
        }
        #expect(!result.isEmpty)
    }
}
