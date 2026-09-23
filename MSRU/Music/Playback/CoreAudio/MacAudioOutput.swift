#if os(macOS)
import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
import Observation

struct MacAudioDevice: Equatable, Identifiable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let nominalRate: Double
    let availableRates: [AudioValueRange]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.uid == rhs.uid && lhs.name == rhs.name
            && lhs.nominalRate == rhs.nominalRate
    }

    func supports(_ rate: Double) -> Bool {
        availableRates.contains { $0.mMinimum <= rate && rate <= $0.mMaximum }
    }
}

struct MacAudioOutputRoute: Equatable {
    let deviceID: AudioDeviceID?
    let deviceUID: String?
    let deviceName: String
    let inputRate: Double?
    let hardwareRate: Double?
    let exclusive: Bool
    let note: String?

    var isNativeRate: Bool {
        guard let inputRate, let hardwareRate else { return false }
        return abs(inputRate - hardwareRate) < 1
    }
}

@MainActor
protocol MacAudioHardware {
    func outputDevices() throws -> [MacAudioDevice]
    func defaultOutputID() throws -> AudioDeviceID
    func setNominalRate(_ rate: Double, deviceID: AudioDeviceID) throws
    func hogOwner(deviceID: AudioDeviceID) throws -> pid_t
    func toggleHog(deviceID: AudioDeviceID) throws -> pid_t
}

enum MacAudioOutputError: LocalizedError {
    case deviceUnavailable
    case hardware(OSStatus)
    case routeFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable: "The selected audio output is unavailable. Choose another device."
        case .hardware(let status): "CoreAudio hardware error \(status)."
        case .routeFailed(let status): "Could not route playback to the selected output (\(status))."
        }
    }
}

@MainActor
final class CoreAudioHardware: MacAudioHardware {
    func outputDevices() throws -> [MacAudioDevice] {
        let ids: [AudioDeviceID] = try array(
            AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices,
            scope: kAudioObjectPropertyScopeGlobal
        )
        return ids.compactMap { id in
            var address = property(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeOutput)
            guard AudioObjectHasProperty(id, &address),
                  let uid = try? string(id, selector: kAudioDevicePropertyDeviceUID),
                  let name = try? string(id, selector: kAudioObjectPropertyName),
                  let nominalRate = try? (scalar(id, selector: kAudioDevicePropertyNominalSampleRate) as Double),
                  let alive = try? (scalar(id, selector: kAudioDevicePropertyDeviceIsAlive) as UInt32), alive != 0,
                  let configuration = try? outputBufferCount(id), configuration > 0 else { return nil }
            let rates: [AudioValueRange] = (try? array(id, selector: kAudioDevicePropertyAvailableNominalSampleRates)) ?? []
            return MacAudioDevice(id: id, uid: uid, name: name, nominalRate: nominalRate, availableRates: rates)
        }
    }

    func defaultOutputID() throws -> AudioDeviceID {
        try scalar(AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    func setNominalRate(_ rate: Double, deviceID: AudioDeviceID) throws {
        var value = rate
        var address = property(kAudioDevicePropertyNominalSampleRate)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Double>.size), &value)
        guard status == noErr else { throw MacAudioOutputError.hardware(status) }
    }

    func hogOwner(deviceID: AudioDeviceID) throws -> pid_t {
        try scalar(deviceID, selector: kAudioDevicePropertyHogMode)
    }

    func toggleHog(deviceID: AudioDeviceID) throws -> pid_t {
        var owner: pid_t = -1
        var address = property(kAudioDevicePropertyHogMode)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<pid_t>.size), &owner)
        guard status == noErr else { throw MacAudioOutputError.hardware(status) }
        return owner
    }

    private func outputBufferCount(_ id: AudioDeviceID) throws -> UInt32 {
        var address = property(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size)
        guard status == noErr else { throw MacAudioOutputError.hardware(status) }
        let memory = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { memory.deallocate() }
        status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, memory)
        guard status == noErr else { throw MacAudioOutputError.hardware(status) }
        let buffers = UnsafeMutableAudioBufferListPointer(memory.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + $1.mNumberChannels }
    }

    private func scalar<T>(_ id: AudioObjectID, selector: AudioObjectPropertySelector) throws -> T {
        let result = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { result.deallocate() }
        var size = UInt32(MemoryLayout<T>.size)
        var address = property(selector)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, result)
        guard status == noErr else { throw MacAudioOutputError.hardware(status) }
        return result.pointee
    }

    private func array<T>(_ id: AudioObjectID, selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> [T] {
        var address = property(selector, scope: scope)
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size)
        guard status == noErr else { throw MacAudioOutputError.hardware(status) }
        let count = Int(size) / MemoryLayout<T>.stride
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: max(1, count))
        defer { pointer.deallocate() }
        status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer)
        guard status == noErr else { throw MacAudioOutputError.hardware(status) }
        return Array(UnsafeBufferPointer(start: pointer, count: Int(size) / MemoryLayout<T>.stride))
    }

    private func string(_ id: AudioObjectID, selector: AudioObjectPropertySelector) throws -> String {
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = property(selector)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        guard status == noErr else { throw MacAudioOutputError.hardware(status) }
        return (value?.takeRetainedValue() as String?) ?? ""
    }
}

private func property(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

/// Owns the selected output and the global HAL settings changed on its behalf.
/// Bit-perfect is intentionally never inferred from an AVAudioEngine rate match.
@MainActor @Observable
final class MacAudioOutputController {
    private let hardware: any MacAudioHardware
    private let preferences: UserDefaults
    private let selectedKey = "playback.output.selectedDeviceUID"
    private let exclusiveKey = "playback.output.exclusive"
    private var originalRates: [AudioDeviceID: Double] = [:]
    private var hoggedDevices: Set<AudioDeviceID> = []
    private var listener: AudioObjectPropertyListenerBlock?
    private var observedAddresses: [AudioObjectPropertyAddress] = []
    private var observedDeviceID: AudioDeviceID?
    private var observedDeviceAddresses: [AudioObjectPropertyAddress] = []
    private var activeDeviceID: AudioDeviceID?

    private(set) var devices: [MacAudioDevice] = []
    private(set) var selectedUID: String?
    private(set) var route: MacAudioOutputRoute?
    private(set) var engineRate: Double?
    private(set) var errorMessage: String?
    private(set) var exclusiveRequested: Bool
    var onSelectedDeviceLost: (() -> Void)?
    var onDefaultDeviceChanged: (() -> Void)?

    init(hardware: any MacAudioHardware = CoreAudioHardware(), preferences: UserDefaults = .standard, observe: Bool = true) {
        self.hardware = hardware
        self.preferences = preferences
        selectedUID = preferences.string(forKey: selectedKey)
        exclusiveRequested = preferences.bool(forKey: exclusiveKey)
        refreshDevices()
        if observe { startObserving() }
    }

    var displayName: String { route?.deviceName ?? devices.first(where: { $0.uid == selectedUID })?.name ?? "System Default" }

    var formatSummary: String {
        guard let route else { return "Output format unavailable" }
        let input = route.inputRate.map { String(format: "%.1f", $0 / 1000) } ?? "unknown"
        let engine = engineRate.map { String(format: "%.1f", $0 / 1000) } ?? "unknown"
        let device = route.hardwareRate.map { String(format: "%.1f", $0 / 1000) } ?? "unknown"
        let conversion = route.isNativeRate && abs((engineRate ?? 0) - (route.hardwareRate ?? -1)) < 1
            ? "Rate matched; digital path unverified" : "Rate conversion possible"
        return "Input \(input) · Engine \(engine) · Device \(device) kHz · \(conversion)"
    }

    func select(_ uid: String?) {
        guard uid != selectedUID else { return }
        releaseHardware()
        stopObservingDevice()
        selectedUID = uid
        preferences.set(uid, forKey: selectedKey)
        route = nil
        activeDeviceID = nil
        engineRate = nil
        refreshDevices()
    }

    func setExclusive(_ enabled: Bool) {
        guard exclusiveRequested != enabled else { return }
        releaseHardware()
        exclusiveRequested = enabled
        preferences.set(enabled, forKey: exclusiveKey)
    }

    func prepare(inputRate: Double?) throws -> MacAudioOutputRoute {
        refreshDevices()
        let device: MacAudioDevice
        if let selectedUID {
            guard let selected = devices.first(where: { $0.uid == selectedUID }) else {
                throw MacAudioOutputError.deviceUnavailable
            }
            device = selected
        } else {
            let defaultID = try hardware.defaultOutputID()
            guard let value = devices.first(where: { $0.id == defaultID }) else {
                throw MacAudioOutputError.deviceUnavailable
            }
            device = value
        }

        var note: String?
        if selectedUID != nil, let inputRate, abs(inputRate - device.nominalRate) >= 1 {
            if device.supports(inputRate) {
                if originalRates[device.id] == nil { originalRates[device.id] = device.nominalRate }
                try hardware.setNominalRate(inputRate, deviceID: device.id)
            } else {
                note = "Device does not support the source sample rate."
            }
        }
        if selectedUID != nil && exclusiveRequested {
            let owner = try hardware.hogOwner(deviceID: device.id)
            if owner == -1 {
                let newOwner = try hardware.toggleHog(deviceID: device.id)
                if newOwner == getpid() { hoggedDevices.insert(device.id) }
            } else if owner == getpid() {
                hoggedDevices.insert(device.id)
            } else {
                note = "Exclusive mode is held by another process."
            }
        }
        let refreshed = try hardware.outputDevices().first(where: { $0.id == device.id }) ?? device
        let result = MacAudioOutputRoute(
            deviceID: selectedUID == nil ? nil : device.id,
            deviceUID: selectedUID == nil ? nil : device.uid,
            deviceName: refreshed.name,
            inputRate: inputRate,
            hardwareRate: refreshed.nominalRate,
            exclusive: hoggedDevices.contains(device.id),
            note: note
        )
        route = result
        activeDeviceID = device.id
        observeDevice(device.id)
        engineRate = nil
        errorMessage = note
        return result
    }

    func updateEngineRate(_ rate: Double?) {
        engineRate = rate
    }

    func releaseHardware() {
        for id in hoggedDevices {
            if (try? hardware.hogOwner(deviceID: id)) == getpid() { _ = try? hardware.toggleHog(deviceID: id) }
        }
        hoggedDevices.removeAll()
        for (id, rate) in originalRates { try? hardware.setNominalRate(rate, deviceID: id) }
        originalRates.removeAll()
    }

    func refreshDevices() {
        do {
            let refreshed = try hardware.outputDevices()
            devices = refreshed
            if let selectedUID, !refreshed.contains(where: { $0.uid == selectedUID }) {
                releaseHardware()
                self.selectedUID = nil
                preferences.removeObject(forKey: selectedKey)
                route = nil
                activeDeviceID = nil
                engineRate = nil
                errorMessage = "Selected output disconnected; using System Default."
                onSelectedDeviceLost?()
                return
            }
            if selectedUID == nil, let activeDeviceID,
               try hardware.defaultOutputID() != activeDeviceID {
                route = nil
                self.activeDeviceID = nil
                onDefaultDeviceChanged?()
                return
            }
            if let activeDeviceID, let updated = refreshed.first(where: { $0.id == activeDeviceID }),
               let route, route.hardwareRate != updated.nominalRate {
                self.route = MacAudioOutputRoute(
                    deviceID: route.deviceID, deviceUID: route.deviceUID,
                    deviceName: updated.name, inputRate: route.inputRate,
                    hardwareRate: updated.nominalRate, exclusive: route.exclusive,
                    note: route.note
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startObserving() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.refreshDevices() }
        }
        listener = block
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
            var address = property(selector)
            if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block) == noErr {
                observedAddresses.append(address)
            }
        }
    }

    private func observeDevice(_ id: AudioDeviceID) {
        guard listener != nil, observedDeviceID != id else { return }
        stopObservingDevice()
        guard let listener else { return }
        observedDeviceID = id
        for selector in [kAudioDevicePropertyNominalSampleRate, kAudioDevicePropertyDeviceIsAlive] {
            var address = property(selector)
            if AudioObjectAddPropertyListenerBlock(id, &address, .main, listener) == noErr {
                observedDeviceAddresses.append(address)
            }
        }
    }

    private func stopObservingDevice() {
        guard let observedDeviceID, let listener else { return }
        for var address in observedDeviceAddresses {
            AudioObjectRemovePropertyListenerBlock(observedDeviceID, &address, .main, listener)
        }
        observedDeviceAddresses.removeAll()
        self.observedDeviceID = nil
    }

    isolated deinit {
        releaseHardware()
        stopObservingDevice()
        if let listener {
            for var address in observedAddresses {
                AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
            }
        }
    }
}

extension AVAudioEngine {
    func routeToMacOutput(deviceID id: AudioDeviceID?) throws {
        if let id {
            guard let unit = outputNode.__audioUnit else { throw MacAudioOutputError.deviceUnavailable }
            var deviceID = id
            let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice,
                                              kAudioUnitScope_Global, 0, &deviceID,
                                              UInt32(MemoryLayout<AudioDeviceID>.size))
            guard status == noErr else { throw MacAudioOutputError.routeFailed(status) }
        }
    }
}
#endif
