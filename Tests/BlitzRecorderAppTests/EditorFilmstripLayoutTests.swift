import XCTest
@testable import BlitzRecorderApp

final class EditorFilmstripLayoutTests: XCTestCase {
    func testZoomedFilmstripKeepsThumbnailCellsCompact() {
        let layout = EditorFilmstripLayout.make(request: .init(
            width: 9_600,
            availableFrameCount: 16
        ))

        XCTAssertLessThanOrEqual(layout.cellWidth, 84)
        XCTAssertGreaterThan(layout.frameIndices.count, 16)
        XCTAssertEqual(layout.frameIndices.first, 0)
        XCTAssertEqual(layout.frameIndices.last, 15)
    }

    func testRequestedDensityTracksRenderedWidthWithinItsMemoryLimit() {
        XCTAssertEqual(EditorFilmstripLayout.requestedFrameCount(width: 672), 8)
        XCTAssertEqual(EditorFilmstripLayout.requestedFrameCount(width: 9_600), 115)
        XCTAssertEqual(EditorFilmstripLayout.requestedFrameCount(width: 40_000), 192)
    }
}
