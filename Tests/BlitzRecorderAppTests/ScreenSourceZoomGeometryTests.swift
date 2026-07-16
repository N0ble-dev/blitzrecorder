import CoreGraphics
@testable import BlitzRecorderApp
import XCTest

final class ScreenSourceZoomGeometryTests: XCTestCase {
    func testZoomCropsContentWithoutChangingTheSourceWindow() throws {
        let crop = try XCTUnwrap(ScreenSourceZoomGeometry.crop(request: .init(
            baseCrop: nil,
            zoom: 1.25
        )))

        XCTAssertEqual(crop.minX, 0.1, accuracy: 0.0001)
        XCTAssertEqual(crop.minY, 0.1, accuracy: 0.0001)
        XCTAssertEqual(crop.width, 0.8, accuracy: 0.0001)
        XCTAssertEqual(crop.height, 0.8, accuracy: 0.0001)
    }

    func testResetRestoresOriginalCrop() throws {
        let base = CGRect(x: 0.2, y: 0.1, width: 0.6, height: 0.7)
        _ = try XCTUnwrap(ScreenSourceZoomGeometry.crop(request: .init(
            baseCrop: base,
            zoom: 1.5
        )))
        let reset = try XCTUnwrap(ScreenSourceZoomGeometry.crop(request: .init(
            baseCrop: base,
            zoom: 1
        )))

        XCTAssertEqual(reset.minX, base.minX, accuracy: 0.0001)
        XCTAssertEqual(reset.minY, base.minY, accuracy: 0.0001)
        XCTAssertEqual(reset.width, base.width, accuracy: 0.0001)
        XCTAssertEqual(reset.height, base.height, accuracy: 0.0001)
    }

    func testResetFullFrameRemovesCrop() {
        let zoomed = ScreenSourceZoomGeometry.crop(request: .init(
            baseCrop: nil,
            zoom: 1.5
        ))
        let reset = ScreenSourceZoomGeometry.crop(request: .init(
            baseCrop: nil,
            zoom: 1
        ))

        XCTAssertNotNil(zoomed)
        XCTAssertNil(reset)
    }

    func testCropScalesInsideExistingSourceRect() {
        let result = ScreenCaptureGeometry.croppedSourceRect(request: .init(
            sourceRect: CGRect(x: 100, y: 50, width: 800, height: 600),
            normalizedCrop: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.5)
        ))

        XCTAssertEqual(result, CGRect(x: 180, y: 170, width: 640, height: 300))
    }
}
