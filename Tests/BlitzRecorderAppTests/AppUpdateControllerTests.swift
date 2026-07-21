import XCTest
@testable import BlitzRecorderApp

final class AppUpdateControllerTests: XCTestCase {
    func testAcceptsSignedHTTPSFeedConfiguration() {
        XCTAssertTrue(AppUpdateController.hasSparkleConfiguration(
            feedURLString: "https://blitzrecorder.com/appcast.xml",
            publicKey: "public-key"
        ))
    }

    func testRejectsMissingOrInsecureFeedConfiguration() {
        XCTAssertFalse(AppUpdateController.hasSparkleConfiguration(
            feedURLString: "http://blitzrecorder.com/appcast.xml",
            publicKey: "public-key"
        ))
        XCTAssertFalse(AppUpdateController.hasSparkleConfiguration(
            feedURLString: "https://blitzrecorder.com/appcast.xml",
            publicKey: "   "
        ))
    }
}
