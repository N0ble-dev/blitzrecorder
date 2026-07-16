struct EditorCanvasOverlaySceneRequest {
    let layoutDraftScene: RecordingScene?
    let canvasDraftScene: RecordingScene?
}

enum EditorCanvasOverlaySceneResolver {
    static func scene(request: EditorCanvasOverlaySceneRequest) -> RecordingScene? {
        request.layoutDraftScene ?? request.canvasDraftScene
    }
}
