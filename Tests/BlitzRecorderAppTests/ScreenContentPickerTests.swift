@testable import BlitzRecorderApp
import XCTest

final class ScreenContentPickerTests: XCTestCase {
    func testActiveRecordingRetargetsExistingStream() {
        XCTAssertEqual(
            ScreenContentPickerPresentationMode.resolve(hasActiveStream: true),
            .updateActiveStream
        )
    }

    func testIdleSelectionStartsNewPickerSession() {
        XCTAssertEqual(
            ScreenContentPickerPresentationMode.resolve(hasActiveStream: false),
            .newSelection
        )
    }
}
