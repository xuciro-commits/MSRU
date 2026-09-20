//
//  AcoustIDConfigurationTests.swift
//  MSRUTests
//
//  Created for Acoustic Metadata Pipeline Architecture.
//

import Foundation
import Testing
@testable import MSRU

@MainActor
struct AcoustIDConfigurationTests {

    @Test
    func defaultKeyIsBuiltInApplicationKey() async {
        let testDefaults = UserDefaults(suiteName: "AcoustIDTestDefaults_\(UUID().uuidString)")!
        let config = AcoustIDConfiguration(defaults: testDefaults)

        let key = await config.apiKey
        #expect(key == AcoustIDConfiguration.defaultClientKey)
        #expect(key == "cSpUJKpD")
    }

    @Test
    func updateAndResetApiKey() async {
        let testDefaults = UserDefaults(suiteName: "AcoustIDTestDefaults_\(UUID().uuidString)")!
        let config = AcoustIDConfiguration(defaults: testDefaults)

        await config.setApiKey("test-custom-key-123")
        let updated = await config.apiKey
        #expect(updated == "test-custom-key-123")

        await config.resetToDefault()
        let reset = await config.apiKey
        #expect(reset == AcoustIDConfiguration.defaultClientKey)
    }

    @Test
    func verifyConnectivityWithDefaultApplicationKey() async {
        let testDefaults = UserDefaults(suiteName: "AcoustIDTestDefaults_\(UUID().uuidString)")!
        let config = AcoustIDConfiguration(defaults: testDefaults)

        // Verifies against live AcoustID endpoint with the standard Application Key
        let result = await config.verifyConnectivity()
        #expect(result.success == true)
        #expect(result.message.contains("200 OK"))
    }

    @Test
    func verifyConnectivityWithInvalidUserKeyReturnsClearDiagnostic() async {
        let testDefaults = UserDefaults(suiteName: "AcoustIDTestDefaults_\(UUID().uuidString)")!
        let config = AcoustIDConfiguration(defaults: testDefaults)
        await config.setApiKey("M7G5ocyWpU") // User Key, not Application Key

        let result = await config.verifyConnectivity()
        #expect(result.success == false)
        #expect(result.message.contains("Invalid API Key") || result.message.contains("API Key 无效"))
        #expect(result.message.contains("User Key"))
    }
}
