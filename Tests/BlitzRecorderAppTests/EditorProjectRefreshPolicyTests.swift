import XCTest
@testable import BlitzRecorderApp

final class EditorProjectRefreshPolicyTests: XCTestCase {
    func testSceneOnlyProjectSaveKeepsActivePlayback() {
        let kind = EditorProjectRefreshPolicy.kind(for: EditorProjectRefreshRequest(
            hasActivePlayback: true,
            isSameProject: true,
            hasSameMedia: true
        ))

        XCTAssertEqual(kind, .sceneTimeline)
    }

    func testMediaChangeReloadsPlayback() {
        let kind = EditorProjectRefreshPolicy.kind(for: EditorProjectRefreshRequest(
            hasActivePlayback: true,
            isSameProject: true,
            hasSameMedia: false
        ))

        XCTAssertEqual(kind, .fullPlayback)
    }
}
