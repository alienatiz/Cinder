import AVFoundation
import CinderCore

public struct MusicInspection: Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public let format: String
    public let seconds: Double
    public let sampleRate: Double
    public let channels: UInt32
    public let bits: UInt32
    public let issue: String?
    public let detail: String

    public static func inspect(_ paths: [String]) -> [MusicInspection] {
        paths.compactMap { path -> MusicInspection? in
            guard !Task.isCancelled else { return nil }
            var codec = "Unknown"
            do {
                let url = URL(fileURLWithPath: path)
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let header = try handle.read(upToCount: 42) ?? Data()
                let dsf = header.prefix(4) == Data("DSD ".utf8)
                let dff = header.prefix(4) == Data("FRM8".utf8) && header.dropFirst(8).prefix(4) == Data("DSD ".utf8)
                if dsf || dff {
                    return Self(path: path, format: dsf ? "DSD / DSF" : "DSD / DFF", seconds: 0, sampleRate: 0, channels: 0, bits: 0, issue: "DSD playback is not supported. Select a PCM file.", detail: "")
                }
                let file = try AVAudioFile(forReading: url)
                let source = file.fileFormat.streamDescription.pointee
                var bitDepth = source.mBitsPerChannel
                if header.count >= 42, header.prefix(4) == Data("fLaC".utf8), header[4] & 127 == 0 {
                    bitDepth = UInt32(((header[20] & 1) << 4) | (header[21] >> 4)) + 1
                }
                let formatID = source.mFormatID
                let bytes = [24, 16, 8, 0].map { UInt8((formatID >> $0) & 255) }
                codec = header.prefix(4) == Data("fLaC".utf8) ? "FLAC" : (String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces).uppercased() ?? "PCM")
                let rate = file.processingFormat.sampleRate
                let channels = file.processingFormat.channelCount
                guard file.length > 0, (1...2).contains(channels), (8000...96000).contains(rate) else {
                    return Self(path: path, format: codec, seconds: rate > 0 ? Double(file.length) / rate : 0, sampleRate: rate, channels: channels, bits: source.mBitsPerChannel, issue: "Music must be nonempty mono/stereo, 8–96 kHz.", detail: "")
                }
                guard let probe = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else { throw CinderError.audio("Cannot allocate music conversion buffers.") }
                try file.read(into: probe)
                guard !Task.isCancelled else { return nil }
                guard probe.frameLength > 0 else { throw CinderError.audio("Music conversion returned no samples.") }
                return Self(path: path, format: codec, seconds: Double(file.length) / rate, sampleRate: rate, channels: channels, bits: bitDepth, issue: nil, detail: "")
            } catch {
                return Self(path: path, format: codec, seconds: 0, sampleRate: 0, channels: 0, bits: 0, issue: "Cannot decode this file.", detail: error.localizedDescription)
            }
        }
    }
}
