import XCTest
@testable import BlitzRecorderApp

final class EditorCanvasOverlaySceneResolverTests: XCTestCase {
    func testCanvasDraftDrivesOverlayWhilePaddingIsBeingEdited() throws {
        var canvasDraft = RecordingScene(settings: RecordingSettings())
        canvasDraft.canvasPadding = 0.1

        let resolved = try XCTUnwrap(EditorCanvasOverlaySceneResolver.scene(request: .init(
            layoutDraftScene: nil,
            canvasDraftScene: canvasDraft
        )))

        XCTAssertEqual(resolved.canvasPadding, 0.1)
    }

    func testLayoutDraftTakesPriorityOverCanvasDraft() throws {
        var layoutDraft = RecordingScene(settings: RecordingSettings())
        layoutDraft.canvasPadding = 0.04
        var canvasDraft = RecordingScene(settings: RecordingSettings())
        canvasDraft.canvasPadding = 0.1

        let resolved = try XCTUnwrap(EditorCanvasOverlaySceneResolver.scene(request: .init(
            layoutDraftScene: layoutDraft,
            canvasDraftScene: canvasDraft
        )))

        XCTAssertEqual(resolved.canvasPadding, 0.04)
    }
}
