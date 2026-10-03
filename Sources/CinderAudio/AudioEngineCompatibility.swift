import AVFoundation
import AudioToolbox
import CoreAudio
import CinderCore

/// Setup-only API differences. Keep device access and graph changes outside the render callback.
enum AudioEngineCompatibility {
    static func selectOutput(_ device: AudioDeviceID, on node: AVAudioOutputNode) throws {
        func select(_ unit: AudioUnit?) throws {
            guard let unit else { throw CinderError.audio("No output audio unit.") }
            var deviceID = device
            let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global, 0, &deviceID, UInt32(MemoryLayout.size(ofValue: deviceID)))
            guard status == noErr else { throw CinderError.audio("Cannot select output (OSStatus \(status)).") }
        }
        if #available(macOS 27.0, *) {
            try node.withAudioUnit { try select($0) }
        } else {
            try select(node.audioUnit)
        }
    }

    static func connect(_ source: AVAudioNode, to destination: AVAudioNode,
                        in engine: AVAudioEngine, format: AVAudioFormat) throws {
        if #available(macOS 27.0, *) {
            try engine.connectNode(source, to: destination, format: format)
        } else {
            engine.connect(source, to: destination, format: format)
        }
    }
}
