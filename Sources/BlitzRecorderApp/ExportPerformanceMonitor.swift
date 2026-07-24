import CoreMedia
import Foundation
import OSLog

struct ExportPerformanceConfiguration {
    let renderSize: CGSize
    let framesPerSecond: Int
    let hardwareEncoderStatus: HardwareVideoEncoderStatus
}

struct ExportPerformanceSnapshot: Codable, Equatable {
    let timestamp: Date
    let width: Int
    let height: Int
    let targetFramesPerSecond: Int
    let framesWritten: Int
    let mediaDuration: Double
    let elapsedDuration: Double
    let throughputFramesPerSecond: Double
    let realtimeFactor: Double
    let videoReadDuration: Double
    let videoAppendDuration: Double
    let audioReadDuration: Double
    let audioAppendDuration: Double
    let writerFinalizationDuration: Double
    let hardwareEncoderAvailable: Bool
    let hardwareEncoderVerified: Bool
    let outputBytes: Int64
}

private struct ExportDurationRecord {
    let duration: Double
    let keyPath: ReferenceWritableKeyPath<ExportPerformanceMonitor, Double>
}

final class ExportPerformanceMonitor: @unchecked Sendable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "dev.blitzreels.blitzrecorder",
        category: "ExportPerformance"
    )
    private static let snapshotURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("BlitzRecorder.export-performance.jsonl")

    private let configuration: ExportPerformanceConfiguration
    private let startedAt = ProcessInfo.processInfo.systemUptime
    private let lock = NSLock()
    private var framesWritten = 0
    private var latestPresentationTime = CMTime.zero
    private var videoReadDuration = 0.0
    private var videoAppendDuration = 0.0
    private var audioReadDuration = 0.0
    private var audioAppendDuration = 0.0
    private var writerFinalizationDuration = 0.0

    init(configuration: ExportPerformanceConfiguration) {
        self.configuration = configuration
        let message = "Export started \(Int(configuration.renderSize.width))x\(Int(configuration.renderSize.height)) "
            + "\(configuration.framesPerSecond)fps hardwareAvailable="
            + "\(configuration.hardwareEncoderStatus.isAvailable) hardwareVerified="
            + "\(configuration.hardwareEncoderStatus.isUsingHardware)"
        Self.logger.notice("\(message, privacy: .public)")
    }

    func didWriteVideoFrame(at presentationTime: CMTime) {
        lock.lock()
        framesWritten += 1
        if presentationTime.isValid {
            latestPresentationTime = presentationTime
        }
        let frameCount = framesWritten
        let mediaSeconds = latestPresentationTime.seconds
        lock.unlock()

        guard frameCount.isMultiple(of: max(1, configuration.framesPerSecond * 5)) else {
            return
        }
        let elapsed = max(0.001, ProcessInfo.processInfo.systemUptime - startedAt)
        let message = "Export progress frames=\(frameCount) mediaSeconds=\(mediaSeconds) "
            + "throughput=\(Double(frameCount) / elapsed)fps"
        Self.logger.info("\(message, privacy: .public)")
    }

    func recordVideoRead(duration: Double) {
        record(ExportDurationRecord(duration: duration, keyPath: \.videoReadDuration))
    }

    func recordVideoAppend(duration: Double) {
        record(ExportDurationRecord(duration: duration, keyPath: \.videoAppendDuration))
    }

    func recordAudioRead(duration: Double) {
        record(ExportDurationRecord(duration: duration, keyPath: \.audioReadDuration))
    }

    func recordAudioAppend(duration: Double) {
        record(ExportDurationRecord(duration: duration, keyPath: \.audioAppendDuration))
    }

    func recordWriterFinalization(duration: Double) {
        record(ExportDurationRecord(duration: duration, keyPath: \.writerFinalizationDuration))
    }

    func finish(outputURL: URL) -> ExportPerformanceSnapshot {
        lock.lock()
        let finalFrameCount = framesWritten
        let mediaDuration = max(0, latestPresentationTime.seconds)
        let finalVideoReadDuration = videoReadDuration
        let finalVideoAppendDuration = videoAppendDuration
        let finalAudioReadDuration = audioReadDuration
        let finalAudioAppendDuration = audioAppendDuration
        let finalWriterFinalizationDuration = writerFinalizationDuration
        lock.unlock()

        let elapsed = max(0.001, ProcessInfo.processInfo.systemUptime - startedAt)
        let outputBytes = ((try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            .map(Int64.init)) ?? 0
        let snapshot = ExportPerformanceSnapshot(
            timestamp: Date(),
            width: Int(configuration.renderSize.width.rounded()),
            height: Int(configuration.renderSize.height.rounded()),
            targetFramesPerSecond: configuration.framesPerSecond,
            framesWritten: finalFrameCount,
            mediaDuration: mediaDuration,
            elapsedDuration: elapsed,
            throughputFramesPerSecond: Double(finalFrameCount) / elapsed,
            realtimeFactor: mediaDuration / elapsed,
            videoReadDuration: finalVideoReadDuration,
            videoAppendDuration: finalVideoAppendDuration,
            audioReadDuration: finalAudioReadDuration,
            audioAppendDuration: finalAudioAppendDuration,
            writerFinalizationDuration: finalWriterFinalizationDuration,
            hardwareEncoderAvailable: configuration.hardwareEncoderStatus.isAvailable,
            hardwareEncoderVerified: configuration.hardwareEncoderStatus.isUsingHardware,
            outputBytes: outputBytes
        )
        Self.append(snapshot)
        let message = "Export finished frames=\(snapshot.framesWritten) elapsed=\(snapshot.elapsedDuration)s "
            + "throughput=\(snapshot.throughputFramesPerSecond)fps realtime=\(snapshot.realtimeFactor)x "
            + "bytes=\(snapshot.outputBytes)"
        Self.logger.notice("\(message, privacy: .public)")
        return snapshot
    }

    private func record(_ request: ExportDurationRecord) {
        lock.lock()
        self[keyPath: request.keyPath] += max(0, request.duration)
        lock.unlock()
    }

    private static func append(_ snapshot: ExportPerformanceSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        var line = data
        line.append(0x0A)
        if !FileManager.default.fileExists(atPath: snapshotURL.path) {
            try? line.write(to: snapshotURL, options: .atomic)
            return
        }
        guard let handle = try? FileHandle(forWritingTo: snapshotURL) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } catch {
            logger.error("Couldn't append export performance snapshot: \(error.localizedDescription)")
        }
    }
}
