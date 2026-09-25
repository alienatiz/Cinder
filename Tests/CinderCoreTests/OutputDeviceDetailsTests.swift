import XCTest
import CoreAudio
@testable import CinderPlatform

final class OutputDeviceDetailsTests: XCTestCase {
    func testUnavailableDeviceDoesNotInventAudioCapabilities() {
        let device = OutputDevice(id: kAudioObjectUnknown, uid: "missing", name: "Missing", transport: 0)
        let details = AudioDevices.details(device)
        XCTAssertNil(details.manufacturer)
        XCTAssertNil(details.sampleRate)
        XCTAssertNil(details.outputChannels)
        XCTAssertTrue(details.availableSampleRates.isEmpty)
    }

    func testDriverRatesKeepRangesAndRejectMalformedValues() {
        let details = AudioDevices.validSampleRates([
            AudioValueRange(mMinimum: 48000, mMaximum: 48000),
            AudioValueRange(mMinimum: 32000, mMaximum: 192000),
            AudioValueRange(mMinimum: 48000, mMaximum: 48000),
            AudioValueRange(mMinimum: 0, mMaximum: 48000),
            AudioValueRange(mMinimum: 96000, mMaximum: 44100),
            AudioValueRange(mMinimum: .nan, mMaximum: 48000),
            AudioValueRange(mMinimum: 48000, mMaximum: .infinity)
        ])
        XCTAssertEqual(details, [32000.0...192000.0, 48000.0...48000.0])
    }
}
