import CoreGraphics

struct EditorSceneTimelineSceneRequest {
    let savedScene: RecordingScene
    let eventIndex: Int
    let draftScene: RecordingScene?
    let draftEventIndex: Int?
}

enum EditorSceneTimelineSceneResolver {
    static func scene(request: EditorSceneTimelineSceneRequest) -> RecordingScene {
        guard request.eventIndex == request.draftEventIndex,
              let draftScene = request.draftScene else {
            return request.savedScene
        }
        return draftScene
    }
}

struct EditorSceneTimelineActiveIndexRequest {
    let eventTimes: [Double]
    let playbackTime: Double
}

enum EditorSceneTimelineActiveIndexResolver {
    static func index(request: EditorSceneTimelineActiveIndexRequest) -> Int? {
        guard !request.eventTimes.isEmpty else { return nil }
        var activeIndex = 0
        for (index, time) in request.eventTimes.enumerated() where time <= request.playbackTime + 0.0001 {
            activeIndex = index
        }
        return activeIndex
    }
}

struct EditorSceneTimelineItemPresentation: Equatable {
    let title: String
    let detail: String?

    static func make(scene: RecordingScene) -> EditorSceneTimelineItemPresentation {
        var details: [String] = []
        if scene.canvasPadding > 0.001 {
            details.append("\(Int((scene.canvasPadding * 100).rounded()))% padding")
        }
        if scene.screenCornerRadius > 0.001 {
            details.append("\(Int((scene.screenCornerRadius * 100).rounded()))% corners")
        }
        if scene.screenShadowEnabled || scene.cameraShadowEnabled {
            details.append("shadow")
        }
        let screenCrop = max(scene.screenCropAmount.x, scene.screenCropAmount.y)
        if screenCrop > 0.001 {
            let visibleFraction = max(0.25, 1 - screenCrop)
            details.append("\(Int((100 / visibleFraction).rounded()))% screen")
        }
        return EditorSceneTimelineItemPresentation(
            title: EditorSceneTitle.title(for: scene),
            detail: details.isEmpty ? nil : details.joined(separator: " · ")
        )
    }
}
