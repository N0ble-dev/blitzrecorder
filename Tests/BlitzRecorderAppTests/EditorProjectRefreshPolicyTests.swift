import XCTest
@testable import BlitzRecorderApp

final class EditorProjectRefreshPolicyTests: XCTestCase {
    func testPausedEditorDoesNotRunDisplayLink() {
        XCTAssertFalse(EditorDisplayLinkPolicy.shouldRun(EditorDisplayLinkRequest(
            isAttachedToWindow: true,
            isPlaying: false
        )))
    }

    func testPlayingEditorRunsDisplayLinkWhileAttached() {
        XCTAssertTrue(EditorDisplayLinkPolicy.shouldRun(EditorDisplayLinkRequest(
            isAttachedToWindow: true,
            isPlaying: true
        )))
    }

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

    func testPlaybackClockUsesLongestSourceInsteadOfShortAudio() {
        let index = EditorPlaybackClockSelection.index(for: [0.5, 3, 2.8])

        XCTAssertEqual(index, 1)
    }

    func testPlaybackClockIgnoresInvalidDurations() {
        let index = EditorPlaybackClockSelection.index(for: [.nan, 2, .infinity])

        XCTAssertEqual(index, 1)
    }
}
