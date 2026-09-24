import XCTest
import AVFoundation
import CinderCore
import CinderDSP
@testable import CinderAudio

/// Exercises the production source callback and mixer without opening a device.
/// These checks do not substitute for headphone/device listening tests.
final class AudioEngineContinuityTests: XCTestCase {
    private func graph(kernel: RenderKernel, rate: Int) throws -> (AVAudioEngine, AVAudioPCMBuffer) {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: Double(rate), channels: 2))
        let engine = AVAudioEngine()
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        let node = kernel.makeSourceNode(format: format)
        engine.attach(node)
        try engine.connectNode(node, to: engine.mainMixerNode, format: format)
        try engine.connectNode(engine.mainMixerNode, to: engine.outputNode, format: format)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096))
        engine.prepare()
        try engine.start()
        return (engine, buffer)
    }

    func testMinuteOfNoiseThroughProductionSourceAndMixerHasNoDropouts() throws {
        for rate in [32000, 44100, 48000, 192000] {
            // .music without PCM is also the full cycle's pink fallback path.
            for program in [PlaybackProgram.pink, .band, .music] {
                let kernel = try RenderKernel(rate: Double(rate), hours: 1.0 / 60, gain: 0, program: program)
                let (engine, buffer) = try graph(kernel: kernel, rate: rate)
                defer { engine.stop() }
                let reference = try XCTUnwrap(cinder_create(Double(rate), 1.0 / 60, 0))
                defer { cinder_destroy(reference) }
                XCTAssertEqual(cinder_program(reference, program.step), 1)
                var left = [Float](repeating: 0, count: 4096), right = left
                // Store only 10 ms window energies, not another minute of PCM.
                let window = rate / 100
                var energies = [Double](repeating: 0, count: 6000)
                var maximumDifference: Float = 0
                var finiteAndBounded = true
                var offset = 0, block = 0
                while offset < rate * 60 {
                    let count = min([127, 1021, 4096][block % 3], rate * 60 - offset)
                    let status = try engine.renderOffline(AVAudioFrameCount(count), to: buffer)
                    guard status == .success, Int(buffer.frameLength) == count else {
                        XCTFail("No render progress: \(status), rate=\(rate), program=\(program)")
                        return
                    }
                    cinder_render(reference, &left, &right, UInt32(count))
                    let channels = try XCTUnwrap(buffer.floatChannelData)
                    for i in 0..<count {
                        let a = channels[0][i], b = channels[1][i]
                        finiteAndBounded = finiteAndBounded && a.isFinite && b.isFinite && abs(a) <= 0.50001 && abs(b) <= 0.50001
                        maximumDifference = max(maximumDifference, max(abs(a - left[i]), abs(b - right[i])))
                        energies[(offset + i) / window] += (Double(a) * Double(a) + Double(b) * Double(b)) * 0.5
                    }
                    offset += count
                    block += 1
                }
                let context = "rate=\(rate), program=\(program)"
                XCTAssertTrue(finiteAndBounded, context)
                XCTAssertLessThan(maximumDifference, 0.00001, context)
                let referenceEnergy = energies[100..<200].reduce(0, +) / 100
                XCTAssertGreaterThan(referenceEnergy, 0, context)
                // Exclude intentional session fades; scan every remaining window,
                // including irregular gaps as well as the four 12-second seams.
                let minimumRatio = sqrt((energies[100..<5900].min() ?? 0) / referenceEnergy)
                XCTAssertGreaterThan(minimumRatio, 0.2, context)
                for second in [12, 24, 36, 48] {
                    let seam = second * 100
                    let ratio = sqrt((energies[seam - 1] + energies[seam]) / (2 * referenceEnergy))
                    XCTAssertGreaterThan(ratio, 0.5, "\(context), seam=\(second)")
                    XCTAssertLessThan(ratio, 2, "\(context), seam=\(second)")
                }
                XCTAssertEqual(cinder_metrics(kernel.pointer).finished, 1, context)
                XCTAssertEqual(try engine.renderOffline(1024, to: buffer), .success)
                let output = try XCTUnwrap(buffer.floatChannelData)
                XCTAssertTrue((0..<Int(buffer.frameLength)).allSatisfy { output[0][$0] == 0 && output[1][$0] == 0 })
                print("Noise continuity: \(context), 60 s, minimum 10 ms RMS ratio=\(minimumRatio), maximum DSP difference=\(maximumDifference)")
            }
        }
    }

    func testSourceRetainsKernelAndResumesAfterPause() throws {
        var owner: RenderKernel? = try RenderKernel(rate: 48000, hours: 1.0 / 60, gain: -30, program: .pink)
        weak let retained = owner
        // AVFoundation nodes can be autoreleased. Check destruction after both
        // the graph's Swift scope and its Objective-C autorelease pool end.
        try autoreleasepool {
            let (engine, buffer) = try graph(kernel: owner!, rate: 48000)
            defer { engine.stop() }
            owner = nil
            XCTAssertNotNil(retained)
            let pointer = try XCTUnwrap(retained?.pointer)
            for _ in 0..<24 { XCTAssertEqual(try engine.renderOffline(4096, to: buffer), .success) }
            cinder_pause(pointer, 1)
            for _ in 0..<12 { XCTAssertEqual(try engine.renderOffline(4096, to: buffer), .success) }
            let paused = cinder_metrics(pointer)
            XCTAssertEqual(paused.paused, 1)
            engine.pause()
            cinder_pause(pointer, 0)
            try engine.start()
            for _ in 0..<12 { XCTAssertEqual(try engine.renderOffline(4096, to: buffer), .success) }
            let resumed = cinder_metrics(pointer)
            XCTAssertEqual(resumed.paused, 0)
            XCTAssertGreaterThan(resumed.frames, paused.frames)
            XCTAssertGreaterThan(resumed.rms, 0)
            engine.stop()
            for node in engine.attachedNodes where node is AVAudioSourceNode { engine.detach(node) }
        }
        XCTAssertNil(retained)
    }
}
