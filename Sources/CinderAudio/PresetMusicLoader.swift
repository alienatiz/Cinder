import AVFoundation
import CinderCore

/// Loads only trusted bundled, mastered loops. Does not apply the user-library
/// 60 Hz high-pass or end fades: both would undo their spectral/loop preparation.
enum PresetMusicLoader {
    static func prepareOwned(_ url: URL, rate: Double, expectedSeconds: Double) throws -> (PreparedSamples, PreparedSamples) {
        guard rate.isFinite, (32000...192000).contains(rate), expectedSeconds.isFinite,
              (1...60).contains(expectedSeconds) else { throw CinderError.audio("Cannot prepare preset music.") }
        try Task.checkCancellation()
        let file = try AVAudioFile(forReading: url)
        let source = file.processingFormat
        guard source.sampleRate == 48000, source.channelCount == 2,
              abs(Double(file.length) / source.sampleRate - expectedSeconds) < 1 / source.sampleRate else {
            throw CinderError.audio("Invalid bundled preset music.")
        }
        let wanted = Int((expectedSeconds * rate).rounded())
        let left = try PreparedSamples(capacity: wanted), right = try PreparedSamples(capacity: wanted)
        guard let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: 4096),
              let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2),
              let converter = AVAudioConverter(from: source, to: format),
              let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else {
            throw CinderError.audio("Cannot prepare preset music.")
        }
        // Supply a second of periodic audio before and after the loop so resampling
        // sees actual neighboring samples at both boundaries, rather than silence.
        let padding: AVAudioFramePosition = 48000
        let suppliedLimit = file.length + padding * 2
        let skip = Int(rate.rounded())
        file.framePosition = file.length - padding
        var supplied: AVAudioFramePosition = 0
        var rendered = 0, emptyBlocks = 0
        var peak: Float = 0
        while left.count < wanted {
            try Task.checkCancellation()
            output.frameLength = 0
            var failure: NSError?, readFailure: Error?
            let status = converter.convert(to: output, error: &failure) { requested, state in
                do {
                    try Task.checkCancellation()
                    guard supplied < suppliedLimit else { state.pointee = .endOfStream; return nil }
                    if file.framePosition == file.length { file.framePosition = 0 }
                    let available = min(file.length - file.framePosition, suppliedLimit - supplied)
                    let count = min(input.frameCapacity, min(requested, AVAudioFrameCount(min(available, 4096))))
                    guard count > 0 else { state.pointee = .noDataNow; return nil }
                    try file.read(into: input, frameCount: count)
                    guard input.frameLength > 0 else { throw CinderError.audio("Invalid bundled preset music.") }
                    supplied += AVAudioFramePosition(input.frameLength)
                    state.pointee = .haveData; return input
                } catch { readFailure = error; state.pointee = .endOfStream; return nil }
            }
            if let readFailure { throw readFailure }
            if let failure { throw failure }
            guard status != .error, let channels = output.floatChannelData else { throw CinderError.audio("Cannot prepare preset music.") }
            let count = Int(output.frameLength)
            for i in 0..<count {
                let position = rendered + i
                if position >= skip && left.count < wanted {
                    let a = channels[0][i], b = channels[1][i]
                    guard a.isFinite, b.isFinite else { throw CinderError.audio("Invalid bundled preset music.") }
                    left.append(a); right.append(b); peak = max(peak, max(abs(a), abs(b)))
                }
            }
            rendered += count
            emptyBlocks = count == 0 ? emptyBlocks + 1 : 0
            guard emptyBlocks < 4, status != .endOfStream || left.count == wanted else {
                throw CinderError.audio("Cannot prepare preset music.")
            }
        }
        guard peak > 0 else { throw CinderError.audio("Invalid bundled preset music.") }
        let gain = min(1, 0.5 / peak)
        if gain < 1 {
            for i in 0..<wanted {
                if i % 4096 == 0 { try Task.checkCancellation() }
                left[i] *= gain; right[i] *= gain
            }
        }
        try Task.checkCancellation()
        return (left, right)
    }
}
