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
    public var connectionLabel: String {
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn: return "Built-in audio"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeBluetooth: return "Bluetooth"
        case kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth LE"
        case kAudioDeviceTransportTypeHDMI: return "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: return "DisplayPort"
        case kAudioDeviceTransportTypeThunderbolt: return "Thunderbolt"
        case kAudioDeviceTransportTypeAirPlay: return "AirPlay"
        case kAudioDeviceTransportTypeAggregate: return "Aggregate device"
        case kAudioDeviceTransportTypeVirtual: return "Virtual device"
        case kAudioDeviceTransportTypePCI: return "PCI"
        case kAudioDeviceTransportTypeFireWire: return "FireWire"
        case kAudioDeviceTransportTypeAVB: return "AVB"
        default: return "Not reported"
        }
    }
}

/// A read-only snapshot supplied by the driver; absent values stay unknown.
public struct OutputDeviceDetails: Equatable, Sendable {
    public let manufacturer: String?
    public let sampleRate: Double?
    public let outputChannels: Int?
    public let availableSampleRates: [ClosedRange<Double>]
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
    /// Called when selecting or refreshing a device, never from the audio callback.
    public static func details(_ device: OutputDevice) -> OutputDeviceDetails {
        let manufacturer = text(device.id, kAudioObjectPropertyManufacturer).trimmingCharacters(in: .whitespacesAndNewlines)
        let rate = sampleRate(device)
        return OutputDeviceDetails(manufacturer: manufacturer.isEmpty ? nil : manufacturer,
                                   sampleRate: rate.isFinite && rate > 0 ? rate : nil,
                                   outputChannels: outputChannelCount(device.id),
                                   availableSampleRates: availableRates(device.id))
    }
    private static func outputChannelCount(_ device: AudioDeviceID) -> Int? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr,
              size >= MemoryLayout<AudioBufferList>.size, size <= 1_048_576 else { return nil }
        let capacity = size
        let memory = UnsafeMutableRawPointer.allocate(byteCount: Int(capacity), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { memory.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, memory) == noErr,
              size <= capacity, size >= MemoryLayout<AudioBufferList>.size else { return nil }
        let list = memory.assumingMemoryBound(to: AudioBufferList.self)
        let offset = MemoryLayout<AudioBufferList>.offset(of: \AudioBufferList.mBuffers)!
        guard Int(list.pointee.mNumberBuffers) <= (Int(size) - offset) / MemoryLayout<AudioBuffer>.stride else { return nil }
        let channels = UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + Int($1.mNumberChannels) }
        return channels > 0 ? channels : nil
    }
    private static func availableRates(_ device: AudioDeviceID) -> [ClosedRange<Double>] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyAvailableNominalSampleRates, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let stride = MemoryLayout<AudioValueRange>.stride
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr,
              size > 0, size <= 65_536, Int(size) % stride == 0 else { return [] }
        let capacity = size
        var ranges = [AudioValueRange](repeating: AudioValueRange(mMinimum: 0, mMaximum: 0), count: Int(size) / stride)
        let result = ranges.withUnsafeMutableBytes { AudioObjectGetPropertyData(device, &address, 0, nil, &size, $0.baseAddress!) }
        guard result == noErr, size <= capacity, Int(size) % stride == 0 else { return [] }
        return validSampleRates(Array(ranges.prefix(Int(size) / stride)))
    }
    static func validSampleRates(_ ranges: [AudioValueRange]) -> [ClosedRange<Double>] {
        let values = ranges.compactMap { range -> ClosedRange<Double>? in
            guard range.mMinimum.isFinite, range.mMaximum.isFinite,
                  range.mMinimum > 0, range.mMaximum >= range.mMinimum else { return nil }
            return range.mMinimum...range.mMaximum
        }
        return Array(Set(values)).sorted {
            $0.lowerBound == $1.lowerBound ? $0.upperBound < $1.upperBound : $0.lowerBound < $1.lowerBound
        }
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
