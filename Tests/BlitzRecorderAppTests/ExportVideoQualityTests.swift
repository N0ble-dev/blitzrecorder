@testable import BlitzRecorderApp
import XCTest

final class ExportVideoQualityTests: XCTestCase {
    func testStandardQualityReducesAutomaticBitrate() {
        XCTAssertEqual(ExportVideoQuality.standard.videoBitrate(baseBitrate: 8_000_000), 5_760_000)
    }

    func testHighQualityPreservesAutomaticBitrate() {
        XCTAssertEqual(ExportVideoQuality.high.videoBitrate(baseBitrate: 8_000_000), 8_000_000)
    }

    func testMaximumQualityRaisesAutomaticBitrate() {
        XCTAssertEqual(ExportVideoQuality.maximum.videoBitrate(baseBitrate: 8_000_000), 12_000_000)
    }

    func testQualityBitrateStaysWithinEncoderLimits() {
        XCTAssertEqual(
            ExportVideoQuality.standard.videoBitrate(baseBitrate: 1_000_000),
            RecordingSettings.minCustomVideoBitrate
        )
        XCTAssertEqual(
            ExportVideoQuality.maximum.videoBitrate(baseBitrate: 100_000_000),
            RecordingSettings.maxCustomVideoBitrate
        )
    }
}
