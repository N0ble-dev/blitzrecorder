import AVFoundation
import CoreImage
import CoreVideo
import Foundation
import Metal

struct MetalExportSourceDescriptor: @unchecked Sendable {
    let kind: SceneLayerKind
    let trackID: CMPersistentTrackID
    let preferredTransform: CGAffineTransform
}

struct MetalExportInstructionRequest {
    let timeRange: CMTimeRange
    let scene: RecordingScene
    let settings: RecordingSettings
    let activeLayerOrder: [SceneLayerKind]
    let sourceDescriptors: [MetalExportSourceDescriptor]
}

final class MetalExportInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening: Bool
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let scene: RecordingScene
    let settings: RecordingSettings
    let sourceDescriptors: [MetalExportSourceDescriptor]

    init(_ request: MetalExportInstructionRequest) {
        timeRange = request.timeRange
        scene = request.scene
        settings = request.settings
        containsTweening = request.scene.canvasBackgroundAnimated
        sourceDescriptors = request.activeLayerOrder.compactMap { kind in
            request.sourceDescriptors.first { $0.kind == kind }
        }
        requiredSourceTrackIDs = sourceDescriptors.map {
            NSNumber(value: $0.trackID)
        }
        super.init()
    }

    func sourceDescriptor(for kind: SceneLayerKind) -> MetalExportSourceDescriptor? {
        sourceDescriptors.first { $0.kind == kind }
    }
}

final class MetalExportVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    let sourcePixelBufferAttributes: [String: any Sendable]? = [
        kCVPixelBufferPixelFormatTypeKey as String: [
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_32BGRA
        ],
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: String]()
    ]
    let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferMetalCompatibilityKey as String: true,
        kCVPixelBufferIOSurfacePropertiesKey as String: [String: String]()
    ]

    private let renderQueue = DispatchQueue(
        label: "blitzrecorder.export.metal-compositor",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let renderGroup = DispatchGroup()
    private let stateLock = NSLock()
    private let rendererPool = MetalExportRendererPool()
    private var generation = 0

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        rendererPool.reset()
    }

    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        stateLock.lock()
        let requestGeneration = generation
        stateLock.unlock()
        renderGroup.enter()
        renderQueue.async { [self] in
            defer { renderGroup.leave() }
            guard isCurrentGeneration(requestGeneration) else {
                asyncVideoCompositionRequest.finishCancelledRequest()
                return
            }
            render(asyncVideoCompositionRequest)
        }
    }

    func cancelAllPendingVideoCompositionRequests() {
        stateLock.lock()
        generation += 1
        stateLock.unlock()
        renderGroup.wait()
    }

    private func render(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? MetalExportInstruction else {
            request.finish(with: MetalExportCompositorError.invalidInstruction)
            return
        }
        guard let outputBuffer = request.renderContext.newPixelBuffer() else {
            request.finish(with: MetalExportCompositorError.outputBufferUnavailable)
            return
        }

        let screenFrame = sourceFrame(SourceFrameRequest(
            kind: .screen,
            instruction: instruction,
            compositionRequest: request
        ))
        let cameraFrame = sourceFrame(SourceFrameRequest(
            kind: .camera,
            instruction: instruction,
            compositionRequest: request
        ))
        guard screenFrame != nil || cameraFrame != nil else {
            request.finish(with: MetalExportCompositorError.sourceFramesUnavailable)
            return
        }

        let renderer = rendererPool.acquire()
        defer { rendererPool.release(renderer) }
        let phase = instruction.scene.canvasBackgroundAnimated
            ? (request.compositionTime.seconds / CanvasAppearance.animationLoopDuration)
                .truncatingRemainder(dividingBy: 1)
            : nil
        let rendered = renderer.render(LiveCompositorImageRenderRequest(
            screenFrame: screenFrame,
            cameraFrame: cameraFrame,
            scene: instruction.scene,
            settings: instruction.settings,
            backgroundPhase: phase,
            outputBuffer: outputBuffer
        ))
        if rendered {
            request.finish(withComposedVideoFrame: outputBuffer)
        } else {
            request.finish(with: MetalExportCompositorError.renderFailed)
        }
    }

    private func sourceFrame(_ request: SourceFrameRequest) -> LiveCompositorImageFrame? {
        guard let descriptor = request.instruction.sourceDescriptor(for: request.kind),
              let pixelBuffer = request.compositionRequest.sourceFrame(byTrackID: descriptor.trackID) else {
            return nil
        }
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        if !descriptor.preferredTransform.isIdentity {
            image = image.transformed(by: descriptor.preferredTransform)
        }
        let extent = image.extent
        if extent.minX != 0 || extent.minY != 0 {
            image = image.transformed(
                by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
            )
        }
        return LiveCompositorImageFrame(image: image)
    }

    private func isCurrentGeneration(_ value: Int) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return value == generation
    }
}

private struct SourceFrameRequest {
    let kind: SceneLayerKind
    let instruction: MetalExportInstruction
    let compositionRequest: AVAsynchronousVideoCompositionRequest
}

private final class MetalExportRendererPool: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore: DispatchSemaphore
    private var renderers: [LiveCompositorRenderer]

    init() {
        let count = max(2, min(4, ProcessInfo.processInfo.activeProcessorCount / 3))
        semaphore = DispatchSemaphore(value: count)
        renderers = (0..<count).map { _ in LiveCompositorRenderer() }
    }

    func acquire() -> LiveCompositorRenderer {
        semaphore.wait()
        lock.lock()
        defer { lock.unlock() }
        return renderers.removeLast()
    }

    func release(_ renderer: LiveCompositorRenderer) {
        lock.lock()
        renderers.append(renderer)
        lock.unlock()
        semaphore.signal()
    }

    func reset() {
        lock.lock()
        for renderer in renderers {
            renderer.reset()
        }
        lock.unlock()
    }
}

private enum MetalExportCompositorError: LocalizedError {
    case invalidInstruction
    case outputBufferUnavailable
    case sourceFramesUnavailable
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .invalidInstruction:
            "The Metal export instruction is invalid."
        case .outputBufferUnavailable:
            "The Metal export buffer pool is unavailable."
        case .sourceFramesUnavailable:
            "The Metal exporter couldn't read a source frame."
        case .renderFailed:
            "The Metal exporter couldn't compose a video frame."
        }
    }
}
