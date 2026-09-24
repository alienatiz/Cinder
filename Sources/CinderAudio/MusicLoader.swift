import AVFoundation
import CinderCore
import Darwin

/// malloc-owned storage transferable to the C renderer without a second PCM cache.
final class PreparedSamples: RandomAccessCollection {
    typealias Index = Int
    typealias Element = Float
    let pointer: UnsafeMutablePointer<Float>
    let capacity: Int
    private(set) var count = 0
    var startIndex: Int { 0 }
    var endIndex: Int { count }
    func index(after index: Int) -> Int { index + 1 }
    func index(before index: Int) -> Int { index - 1 }
    func index(_ index: Int, offsetBy distance: Int) -> Int { index + distance }
    func distance(from start: Int, to end: Int) -> Int { end - start }
    private var ownsMemory = true
    init(capacity: Int) throws {
        guard (0...32_000_000).contains(capacity) else { throw CinderError.audio("Music buffers exceed 256 MB.") }
        guard let memory = calloc(Swift.max(1, capacity), MemoryLayout<Float>.size) else { throw CinderError.audio("Cannot allocate music conversion buffers.") }
        pointer = memory.assumingMemoryBound(to: Float.self); self.capacity = capacity
    }
    subscript(index: Int) -> Float {
        get { pointer[index] }
        set { pointer[index] = newValue }
    }
    func append(_ value: Float) { precondition(count < capacity); pointer[count] = value; count += 1 }
    func transferOwnership() { ownsMemory = false }
    deinit { if ownsMemory { free(pointer) } }
}

public enum MusicLoader {
    public static func duration(_ paths: [String]) throws -> Double {
        guard paths.count <= 100 else { throw CinderError.audio("Select at most 100 files.") }
        var total = 0.0
        for path in paths {
            try Task.checkCancellation()
            let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            let f = file.processingFormat
            guard file.length > 0, (1...2).contains(f.channelCount), (8000...96000).contains(f.sampleRate) else {
                throw CinderError.audio("Music must be nonempty mono/stereo, 8–96 kHz.")
            }
            total += Double(file.length) / f.sampleRate
            guard total <= 600 else { throw CinderError.audio("Select at most 10 minutes of music in total.") }
        }
        return total
    }
    // Tests and playback use the same owned buffers; no array-copy convenience path.
    static func prepareOwned(_ paths: [String], rate: Double) throws -> (PreparedSamples, PreparedSamples) {
        guard rate.isFinite, (32000...192000).contains(rate) else { throw CinderError.audio("Unsupported output format.") }
        try Task.checkCancellation()
        let seconds = try duration(paths)
        guard seconds * rate * 8 <= 256_000_000 else { throw CinderError.audio("Music buffers exceed 256 MB. Use shorter music or a lower output sample rate.") }
        let capacity = min(32_000_000, Int(ceil(seconds * rate)) + 4096 * paths.count)
        var left = try PreparedSamples(capacity: capacity), right = try PreparedSamples(capacity: capacity)
        for path in paths {
            try Task.checkCancellation()
            let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            guard let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096),
                  let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2),
                  let converter = AVAudioConverter(from: file.processingFormat, to: format),
                  let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else {
                throw CinderError.audio("Cannot allocate music conversion buffers.")
            }
            let start = left.count
            var prePeak: Float = 1
            var ended = false
            var emptyBlocks = 0
            while !ended {
                try Task.checkCancellation()
                output.frameLength = 0
                var failure: NSError?
                var readFailure: Error?
                let status = converter.convert(to: output, error: &failure) { requested, state in
                    do {
                        try Task.checkCancellation()
                        let available = file.length - file.framePosition
                        guard available > 0 else { state.pointee = .endOfStream; return nil }
                        let count = min(input.frameCapacity, min(requested, AVAudioFrameCount(min(available, 4096))))
                        guard count > 0 else { state.pointee = .noDataNow; return nil }
                        try file.read(into: input, frameCount: count)
                        state.pointee = input.frameLength > 0 ? .haveData : .endOfStream
                        return input.frameLength > 0 ? input : nil
                    } catch {
                        readFailure = error; state.pointee = .endOfStream; return nil
                    }
                }
                try Task.checkCancellation()
                if let readFailure { throw readFailure }
                if let failure { throw failure }
                guard status != .error, let channels = output.floatChannelData else { throw CinderError.audio("Music conversion failed.") }
                let count = Int(output.frameLength)
                guard left.count + count <= capacity else { throw CinderError.audio("Music buffers exceed 256 MB.") }
                for i in 0..<count {
                    let a = channels[0][i], b = channels[1][i]
                    guard a.isFinite, b.isFinite else { throw CinderError.audio("Music contains invalid samples.") }
                    prePeak = max(prePeak, max(abs(a), abs(b)))
                    left.append(a); right.append(b)
                }
                ended = status == .endOfStream
                emptyBlocks = count == 0 ? emptyBlocks + 1 : 0
                guard ended || emptyBlocks < 4 else { throw CinderError.audio("Music converter made no progress.") }
            }
            let end = left.count
            guard end > start else { throw CinderError.audio("Music conversion returned no samples.") }
            // Condition cached ranges in place without full-file temporary arrays.
            func condition(_ values: inout PreparedSamples) throws -> Float {
                var low = 0.0, dc = 0.0
                var peak: Float = 1
                let lp = 1 - exp(-2 * Double.pi * min(14000, rate * 0.45) / rate)
                let hp = 1 - exp(-2 * Double.pi * 60 / rate)
                for i in start..<end {
                    if i % 4096 == 0 { try Task.checkCancellation() }
                    low += lp * (Double(values[i] / prePeak) - low); dc += hp * (low - dc)
                    values[i] = Float(low - dc); peak = max(peak, abs(values[i]))
                }
                return peak
            }
            let leftPeak = try condition(&left), rightPeak = try condition(&right)
            let peak = max(leftPeak, rightPeak)
            for i in start..<end {
                if i % 4096 == 0 { try Task.checkCancellation() }
                let fade = Float(min(1, Double(min(i - start, end - 1 - i)) / (rate * 0.05)))
                left[i] *= 0.5 * fade / peak; right[i] *= 0.5 * fade / peak
            }
        }
        return (left, right)
    }
}
