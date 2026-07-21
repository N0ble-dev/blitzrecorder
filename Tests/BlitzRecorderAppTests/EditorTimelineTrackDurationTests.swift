import XCTest
@testable import BlitzRecorderApp

final class EditorTimelineTrackDurationTests: XCTestCase {
    func testTrackEndsAtStopWhenRawCaptureIncludesStartupFrames() {
        let duration = EditorTimelineTrackDuration.resolve(.init(
            rawDuration: 25.968,
            playbackDuration: 19.940
        ))

        XCTAssertEqual(duration, 19.940, accuracy: 0.001)
    }

    func testTrackKeepsEarlierEndWhenSourceIsShorterThanPlayback() {
        let duration = EditorTimelineTrackDuration.resolve(.init(
            rawDuration: 16,
            playbackDuration: 20
        ))

        XCTAssertEqual(duration, 16, accuracy: 0.001)
    }
}
