import AVFoundation
import AudioToolbox
import Darwin
import CinderCore
import CinderDSP
import CinderPlatform

// Preparation owns the mutable buffers until the render node is installed. After
// that, only the render callback advances DSP state; controls/metrics use C atomics.
final class RenderKernel: @unchecked Sendable {
    let pointer: OpaquePointer
    init(rate: Double, hours: Double, gain: Double, program: PlaybackProgram) throws {
        guard let pointer = cinder_create(rate, hours, gain) else { throw CinderError.audio("Cannot prepare signal buffers.") }
        self.pointer = pointer
        guard cinder_program(pointer, program.step) != 0 else { throw CinderError.audio("Invalid playback program.") }
    }
    func loadMusic(_ music: [String], rate: Double) throws {
        if !music.isEmpty {
            let (left, right) = try MusicLoader.prepareOwned(music, rate: rate)
            try Task.checkCancellation()
            guard cinder_music_take(pointer, left.pointer, right.pointer, UInt32(left.count)) != 0 else { throw CinderError.audio("Cannot prepare music buffer.") }
            left.transferOwnership(); right.transferOwnership()
        }
    }
    func loadPreset(_ preset: PresetMusic, rate: Double, url: URL) throws {
        let (left, right) = try PresetMusicLoader.prepareOwned(url, rate: rate, expectedSeconds: preset.loopSeconds)
        try Task.checkCancellation()
        guard cinder_music_take(pointer, left.pointer, right.pointer, UInt32(left.count)) != 0 else {
            throw CinderError.audio("Cannot prepare preset music.")
        }
        left.transferOwnership(); right.transferOwnership()
    }
    // Construct outside MainActor so the audio callback never inherits UI actor
    // isolation. Capturing the owner keeps PCM alive until the node is released.
    func makeSourceNode(format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { @Sendable [self] isSilence, _, count, list in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            guard buffers.count == 2,
                  buffers[0].mNumberChannels == 1, buffers[1].mNumberChannels == 1,
                  Int(buffers[0].mDataByteSize) >= Int(count) * MemoryLayout<Float>.size,
                  Int(buffers[1].mDataByteSize) >= Int(count) * MemoryLayout<Float>.size,
                  let left = buffers[0].mData, let right = buffers[1].mData else {
                for buffer in buffers { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
                isSilence.pointee = true
                return kAudioUnitErr_FormatNotSupported
            }
            isSilence.pointee = false
            cinder_render(pointer, left.assumingMemoryBound(to: Float.self), right.assumingMemoryBound(to: Float.self), count)
            return noErr
        }
    }
    deinit { cinder_destroy(pointer) }
}

@MainActor public final class PlaybackEngine {
    private var engine: AVAudioEngine?
    private var source: AVAudioSourceNode?
    private var kernel: RenderKernel?
    private var rate: Double = 48000
    private var generation = 0
    private var preparation: Task<RenderKernel, Error>?
    private var notification: NSObjectProtocol?
    public var configurationChanged: (() -> Void)?
    public init() {}

    public func start(device: OutputDevice, settings: SessionSettings, music: [String] = [], presetURL: URL? = nil) async throws {
        shutdown()
        try settings.validatePlayback(); try AudioDevices.validate(device)
        let ticket = generation
        let candidate = AVAudioEngine()
        try candidate.outputNode.withAudioUnit { unit in
            guard let unit else { throw CinderError.audio("No output audio unit.") }
            var deviceID = device.id
            let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &deviceID, UInt32(MemoryLayout.size(ofValue: deviceID)))
            guard status == noErr else { throw CinderError.audio("Cannot select output (OSStatus \(status)).") }
        }
        let sampleRate = candidate.outputNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate >= 32000, sampleRate <= 192000,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw CinderError.audio("Unsupported output format.")
        }
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let result = try RenderKernel(rate: sampleRate, hours: Double(settings.durationMinutes) / 60, gain: settings.gainDB, program: settings.selectedProgram)
            try Task.checkCancellation()
            if settings.selectedProgram.usesMusic {
                if settings.selectedMusicSource == .preset {
                    guard let presetURL else { throw CinderError.audio("Missing bundled preset music.") }
                    try result.loadPreset(settings.selectedMusicPreset, rate: sampleRate, url: presetURL)
                }
                else { try result.loadMusic(music, rate: sampleRate) }
            }
            try Task.checkCancellation()
            return result
        }
        preparation = task
        defer { if generation == ticket { preparation = nil } }
        let prepared = try await task.value
        guard generation == ticket else { throw CancellationError() }
        try AudioDevices.validate(device)
        guard candidate.outputNode.outputFormat(forBus: 0).sampleRate == sampleRate else { throw CinderError.deviceChanged }
        let node = prepared.makeSourceNode(format: format)
        candidate.attach(node)
        try candidate.connectNode(node, to: candidate.mainMixerNode, format: format)
        candidate.prepare()
        try candidate.start()
        engine = candidate; source = node; kernel = prepared; rate = sampleRate
        notification = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: candidate, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == ticket else { return }
                self.configurationChanged?()
            }
        }
    }
    public func setGain(_ db: Double) {
        guard (try? GainPolicy.validate(db)) != nil else { return }
        if let kernel { cinder_gain(kernel.pointer, db) }
    }
    public func pause() { if let kernel { cinder_pause(kernel.pointer, 1) } }
    /// Called only after the DSP fade has acknowledged pause.
    public func suspendAfterPause() { engine?.pause() }
    public func resume() throws {
        guard let kernel, let engine else { throw CinderError.audio("No paused audio engine.") }
        _ = cinder_metrics(kernel.pointer) // Discard the peak retained before suspension.
        cinder_pause(kernel.pointer, 0)
        try engine.start()
    }
    public func stop() { if let kernel { cinder_stop(kernel.pointer) } else { shutdown() } }
    public func snapshot() -> AudioSnapshot {
        guard let kernel else { return AudioSnapshot() }
        let metrics = cinder_metrics(kernel.pointer)
        var value = AudioSnapshot()
        value.elapsed = Double(metrics.frames) / rate; value.sound = Double(metrics.sound_frames) / rate
        value.peakDB = metrics.peak > 0 ? 20 * log10(Double(metrics.peak)) : -.infinity
        value.rmsDB = metrics.rms > 0 ? 20 * log10(Double(metrics.rms)) : -.infinity
        value.paused = metrics.paused != 0; value.finished = metrics.finished != 0
        return value
    }
    public func shutdown() {
        generation += 1
        preparation?.cancel(); preparation = nil
        if let notification { NotificationCenter.default.removeObserver(notification) }
        notification = nil
        engine?.stop()
        if let source { engine?.detach(source) }
        source = nil; engine = nil; kernel = nil
    }
}
