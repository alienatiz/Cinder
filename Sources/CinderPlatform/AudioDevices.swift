import Foundation
import CoreAudio
import CinderCore
import Darwin

public struct OutputDevice: Identifiable, Equatable, Sendable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let transport: UInt32
    public var builtInHeadphones: Bool { transport == kAudioDeviceTransportTypeBuiltIn && name.lowercased().contains("headphone") }
}

public enum AudioDevices {
    public static var modelIdentifier: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "Unknown Mac" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return "Unknown Mac" }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
    public static func sampleRate(_ device: OutputDevice) -> Double {
        var value = 0.0, size = UInt32(MemoryLayout<Double>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyNominalSampleRate, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(device.id, &address, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }
    private static func text(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        // Core Audio returns an owned CFString for the name and device UID.
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout.size(ofValue: value))
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr,
              let value else { return "" }
        return value.takeRetainedValue() as String
    }
    public static func outputs() throws -> [OutputDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { throw CinderError.audio("Cannot enumerate output devices.") }
        guard size > 0 else { return [] }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        let result = devices.withUnsafeMutableBytes { AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, $0.baseAddress!) }
        guard result == noErr else { throw CinderError.audio("Cannot read output devices.") }
        return devices.compactMap { device in
            var config = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
            var bytes: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(device, &config, 0, nil, &bytes) == noErr, bytes >= MemoryLayout<AudioBufferList>.size else { return nil }
            let memory = UnsafeMutableRawPointer.allocate(byteCount: Int(bytes), alignment: MemoryLayout<AudioBufferList>.alignment)
            defer { memory.deallocate() }
            guard AudioObjectGetPropertyData(device, &config, 0, nil, &bytes, memory) == noErr else { return nil }
            let buffers = UnsafeMutableAudioBufferListPointer(memory.assumingMemoryBound(to: AudioBufferList.self))
            guard buffers.reduce(0, { $0 + Int($1.mNumberChannels) }) >= 2 else { return nil }
            var transport: UInt32 = 0; var transportSize = UInt32(MemoryLayout<UInt32>.size)
            var transportAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            _ = AudioObjectGetPropertyData(device, &transportAddress, 0, nil, &transportSize, &transport)
            let uid = text(device, kAudioDevicePropertyDeviceUID)
            guard !uid.isEmpty else { return nil }
            return OutputDevice(id: device, uid: uid, name: text(device, kAudioObjectPropertyName), transport: transport)
        }
    }
    public static func validate(_ device: OutputDevice) throws {
        guard try outputs().contains(where: { $0.id == device.id && $0.uid == device.uid }) else { throw CinderError.deviceChanged }
    }
}

@MainActor public final class DeviceMonitor {
    private var listener: AudioObjectPropertyListenerBlock?
    private var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    public init() {}
    public func start(_ changed: @escaping @MainActor () -> Void) {
        stop()
        let block: AudioObjectPropertyListenerBlock = { _, _ in Task { @MainActor in changed() } }
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, block) == noErr { listener = block }
    }
    public func stop() {
        if let listener { AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener) }
        listener = nil
    }
}
