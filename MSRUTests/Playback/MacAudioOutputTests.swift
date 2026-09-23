#if os(macOS)
import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
import Testing
@testable import MSRU

@MainActor
@Suite("macOS audio output routing", .serialized)
struct MacAudioOutputTests {
    @Test("CoreAudio enumerates the current default output without changing it")
    func realHardwareEnumeration() throws {
        let hardware = CoreAudioHardware()
        let defaultID = try hardware.defaultOutputID()
        let devices = try hardware.outputDevices()
        let device = devices.first(where: { $0.id == defaultID })
        #expect(device != nil, "default=\(defaultID), devices=\(devices.map(\.id))")
        #expect((device?.nominalRate ?? 0) > 0)
        #expect(device?.uid.isEmpty == false)

        let engine = AVAudioEngine()
        try engine.routeToMacOutput(deviceID: defaultID)
        guard let unit = engine.outputNode.__audioUnit else {
            Issue.record("AVAudioEngine did not expose an output AudioUnit")
            return
        }
        var routedID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioUnitGetProperty(unit, kAudioOutputUnitProperty_CurrentDevice,
                                          kAudioUnitScope_Global, 0, &routedID, &size)
        #expect(status == noErr)
        #expect(routedID == defaultID)
    }

    private func device(
        _ id: AudioDeviceID, _ uid: String, rate: Double = 48_000,
        supported: [Double] = [44_100, 48_000]
    ) -> MacAudioDevice {
        MacAudioDevice(
            id: id, uid: uid, name: "Test DAC \(id)", nominalRate: rate,
            availableRates: supported.map { AudioValueRange(mMinimum: $0, mMaximum: $0) }
        )
    }

    private func controller(_ hardware: FakeAudioHardware) -> MacAudioOutputController {
        let preferences = UserDefaults(suiteName: UUID().uuidString)!
        return MacAudioOutputController(hardware: hardware, preferences: preferences, observe: false)
    }

    @Test("A selected DAC switches to the source rate and restores its previous rate")
    func nativeRateAndRestore() throws {
        let hardware = FakeAudioHardware(devices: [device(10, "dac")], defaultID: 10)
        let output = controller(hardware)
        output.select("dac")
        let route = try output.prepare(inputRate: 44_100)
        output.updateEngineRate(44_100)
        #expect(route.deviceID == 10)
        #expect(route.isNativeRate)
        #expect(hardware.devices[0].nominalRate == 44_100)
        #expect(output.formatSummary.contains("Rate matched; digital path unverified"))
        output.select(nil)
        #expect(hardware.devices[0].nominalRate == 48_000)
    }

    @Test("Unsupported source rate is reported as a possible conversion")
    func unsupportedRate() throws {
        let hardware = FakeAudioHardware(devices: [device(10, "dac", supported: [48_000])], defaultID: 10)
        let output = controller(hardware)
        output.select("dac")
        let route = try output.prepare(inputRate: 44_100)
        output.updateEngineRate(48_000)
        #expect(!route.isNativeRate)
        #expect(route.note?.contains("does not support") == true)
        #expect(output.formatSummary.contains("Rate conversion possible"))
    }

    @Test("Exclusive ownership is only released when this process acquired it")
    func exclusiveOwnership() throws {
        let hardware = FakeAudioHardware(devices: [device(10, "dac")], defaultID: 10)
        let output = controller(hardware)
        output.select("dac")
        output.setExclusive(true)
        let route = try output.prepare(inputRate: 48_000)
        #expect(route.exclusive)
        #expect(hardware.owners[10] == getpid())
        output.releaseHardware()
        #expect(hardware.owners[10] == -1)

        hardware.owners[10] = 999_999
        let blocked = try output.prepare(inputRate: 48_000)
        #expect(!blocked.exclusive)
        #expect(blocked.note?.contains("another process") == true)
        output.releaseHardware()
        #expect(hardware.owners[10] == 999_999)
    }

    @Test("Disconnecting the selected DAC returns to System Default and requests recovery")
    func lostDevice() throws {
        let hardware = FakeAudioHardware(devices: [device(10, "dac"), device(20, "system")], defaultID: 20)
        let output = controller(hardware)
        output.select("dac")
        _ = try output.prepare(inputRate: 44_100)
        var recoveries = 0
        output.onSelectedDeviceLost = { recoveries += 1 }
        hardware.devices.removeAll { $0.uid == "dac" }
        output.refreshDevices()
        #expect(recoveries == 1)
        #expect(output.selectedUID == nil)
        #expect(output.errorMessage?.contains("disconnected") == true)
        #expect(try output.prepare(inputRate: 44_100).deviceName == "Test DAC 20")
    }

    @Test("Changing the system default requests recovery when no DAC is selected")
    func defaultDeviceChange() throws {
        let hardware = FakeAudioHardware(devices: [device(10, "first"), device(20, "second")], defaultID: 10)
        let output = controller(hardware)
        _ = try output.prepare(inputRate: 48_000)
        var recoveries = 0
        output.onDefaultDeviceChanged = { recoveries += 1 }
        hardware.defaultID = 20
        output.refreshDevices()
        #expect(recoveries == 1)
        #expect(try output.prepare(inputRate: 48_000).deviceName == "Test DAC 20")
    }
}

@MainActor
private final class FakeAudioHardware: MacAudioHardware {
    var devices: [MacAudioDevice]
    var defaultID: AudioDeviceID
    var owners: [AudioDeviceID: pid_t] = [:]

    init(devices: [MacAudioDevice], defaultID: AudioDeviceID) {
        self.devices = devices
        self.defaultID = defaultID
    }

    func outputDevices() throws -> [MacAudioDevice] { devices }
    func defaultOutputID() throws -> AudioDeviceID { defaultID }
    func setNominalRate(_ rate: Double, deviceID: AudioDeviceID) throws {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else {
            throw MacAudioOutputError.deviceUnavailable
        }
        let old = devices[index]
        devices[index] = MacAudioDevice(
            id: old.id, uid: old.uid, name: old.name,
            nominalRate: rate, availableRates: old.availableRates
        )
    }
    func hogOwner(deviceID: AudioDeviceID) throws -> pid_t { owners[deviceID] ?? -1 }
    func toggleHog(deviceID: AudioDeviceID) throws -> pid_t {
        let owner: pid_t = owners[deviceID] == getpid() ? -1 : getpid()
        owners[deviceID] = owner
        return owner
    }
}
#endif
