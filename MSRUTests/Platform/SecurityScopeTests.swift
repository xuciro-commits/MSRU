//
//  SecurityScopeTests.swift
//  MSRUTests
//
//  Canonical tests for SecurityScopePolicy invariants and sandbox adaptation.
//

import Foundation
import Testing
import MusicDomain
@testable import MSRU

@Suite("Security Scope Policy Invariants")
struct SecurityScopeTests {

    @Test("Sandbox detection and bookmark options conform to runtime environment")
    func sandboxDetectionAndBookmarkOptions() {
        let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

        #expect(SecurityScopePolicy.isSandboxed == isSandboxed)

        if isSandboxed {
            #expect(SecurityScopePolicy.bookmarkCreationOptions == .withSecurityScope)
            #expect(SecurityScopePolicy.bookmarkResolutionOptions == .withSecurityScope)
        } else {
            #expect(SecurityScopePolicy.bookmarkCreationOptions == [])
            #expect(SecurityScopePolicy.bookmarkResolutionOptions == [])
        }
    }

    @Test("Coordinate access executes synchronous block and preserves returned value")
    func coordinateAccessSynchronous() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var executed = false

        let result = SecurityScopePolicy.coordinateAccess(to: tempURL) { url in
            executed = true
            #expect(url == tempURL)
            return "access-granted"
        }

        #expect(executed == true)
        #expect(result == "access-granted")
    }

    @Test("Coordinate access async executes asynchronous block and preserves returned value")
    func coordinateAccessAsynchronous() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var executed = false

        let result = await SecurityScopePolicy.coordinateAccessAsync(to: tempURL) { url in
            executed = true
            #expect(url == tempURL)
            return 42
        }

        #expect(executed == true)
        #expect(result == 42)
    }

    @Test("Invalid bookmark data resolution returns nil safely without throwing or crashing")
    func resolveBookmarkInvalidData() {
        let corruptData = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01, 0x02])
        let result = SecurityScopePolicy.resolveBookmark(corruptData)
        #expect(result == nil)

        let emptyData = Data()
        let emptyResult = SecurityScopePolicy.resolveBookmark(emptyData)
        #expect(emptyResult == nil)
    }

    @Test("Local volume detection correctly identifies local temporary directory")
    func localVolumeDetection() {
        let tempURL = FileManager.default.temporaryDirectory
        #expect(SecurityScopePolicy.isLocalVolume(tempURL) == true)
    }
}
