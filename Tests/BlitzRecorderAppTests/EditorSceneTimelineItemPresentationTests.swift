import XCTest
@testable import BlitzRecorderApp

final class EditorSceneTimelineItemPresentationTests: XCTestCase {
    func testPresentationConveysPersistentSceneEffects() {
        var settings = RecordingSettings()
        settings.enabledSources = [.screen, .camera]
        var scene = RecordingScene(settings: settings)
        scene.canvasPadding = 0.08
        scene.screenCornerRadius = 0.06
        scene.screenShadowEnabled = true
        scene.screenCropAmount = CGPoint(x: 0.2, y: 0.2)

        let presentation = EditorSceneTimelineItemPresentation.make(scene: scene)

        XCTAssertEqual(presentation.title, "Screen + Camera")
        XCTAssertEqual(presentation.detail, "8% padding · 6% corners · shadow · 125% screen")
    }

    func testDraftSceneReplacesSavedSceneOnlyForMatchingSegment() {
        var savedScene = RecordingScene(settings: RecordingSettings())
        savedScene.canvasPadding = 0
        var draftScene = savedScene
        draftScene.canvasPadding = 0.1

        let matching = EditorSceneTimelineSceneResolver.scene(request: .init(
            savedScene: savedScene,
            eventIndex: 2,
            draftScene: draftScene,
            draftEventIndex: 2
        ))
        let different = EditorSceneTimelineSceneResolver.scene(request: .init(
            savedScene: savedScene,
            eventIndex: 1,
            draftScene: draftScene,
            draftEventIndex: 2
        ))

        XCTAssertEqual(matching.canvasPadding, 0.1)
        XCTAssertEqual(different.canvasPadding, 0)
    }

    func testActiveSegmentTracksPlaybackBoundaries() {
        let beforeCut = EditorSceneTimelineActiveIndexResolver.index(request: .init(
            eventTimes: [0, 3, 7],
            playbackTime: 2.99
        ))
        let atCut = EditorSceneTimelineActiveIndexResolver.index(request: .init(
            eventTimes: [0, 3, 7],
            playbackTime: 3
        ))

        XCTAssertEqual(beforeCut, 0)
        XCTAssertEqual(atCut, 1)
    }
}
