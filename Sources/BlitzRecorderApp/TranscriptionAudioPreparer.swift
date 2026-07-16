import AVFoundation
import Foundation

enum TranscriptionMediaSource: Equatable, Sendable {
    case project(URL)
    case recording(URL)

    var key: String {
        switch self {
        case .project(let url):
            return url.path
        case .recording(let url):
            return url.path
        }
    }
}

struct PreparedTranscriptionAudio: Sendable {
    let mediaPath: String
    let audioURL: URL
    let artifactLocations: TranscriptArtifactStore.Locations
    let temporaryURL: URL
}

struct TranscriptionAudioPreparer {
    private struct AudioInput {
        let url: URL
        let trackIndex: Int
        let sourceStart: CMTime
        let volume: Float
    }

    private struct ExportRequest {
        let inputs: [AudioInput]
        let outputURL: URL
    }

    private let fileStore = TakeFileStore()
    private let artifactStore = TranscriptArtifactStore()

    func prepare(_ source: TranscriptionMediaSource) async throws -> PreparedTranscriptionAudio {
        let outputURL = try temporaryAudioURL()
        switch source {
        case .project(let projectURL):
            let project = try fileStore.loadRecordingProject(at: projectURL)
            let inputs = projectAudioInputs(project)
            guard !inputs.isEmpty else {
                throw RecorderError.speechUnavailable
            }
            try await export(ExportRequest(inputs: inputs, outputURL: outputURL))
            return PreparedTranscriptionAudio(
                mediaPath: project.finalVideoPath ?? project.projectPath,
                audioURL: outputURL,
                artifactLocations: artifactStore.locations(for: project),
                temporaryURL: outputURL
            )
        case .recording(let recordingURL):
            let inputs = try await recordingAudioInputs(recordingURL)
            guard !inputs.isEmpty else {
                throw RecorderError.speechUnavailable
            }
            try await export(ExportRequest(inputs: inputs, outputURL: outputURL))
            return PreparedTranscriptionAudio(
                mediaPath: recordingURL.path,
                audioURL: outputURL,
                artifactLocations: artifactStore.locations(for: recordingURL),
                temporaryURL: outputURL
            )
        }
    }

    private func projectAudioInputs(_ project: RecordingProject) -> [AudioInput] {
        project.sources.compactMap { source in
            guard source.exists,
                  source.role == "microphone"
                    || source.role == "systemAudio" else {
                return nil
            }
            let url = URL(fileURLWithPath: source.path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            let sourceTimelineOffset = project.sourceTimelineOffsetSeconds[source.role] ?? 0
            let sourceStart = max(
                0,
                project.timelineTrimOffsetSeconds - sourceTimelineOffset
            )
            let volume: Float
            if source.role == "microphone" {
                volume = Float(project.settings.microphoneGain ?? 1)
            } else {
                volume = Float(project.settings.systemAudioGain ?? 1)
            }
            return AudioInput(
                url: url,
                trackIndex: 0,
                sourceStart: CMTime(seconds: sourceStart, preferredTimescale: 600),
                volume: max(0, min(2, volume))
            )
        }
    }

    private func recordingAudioInputs(_ url: URL) async throws -> [AudioInput] {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        var inputs: [AudioInput] = []
        for (index, track) in tracks.enumerated() {
            let timeRange = try await track.load(.timeRange)
            inputs.append(AudioInput(
                url: url,
                trackIndex: index,
                sourceStart: timeRange.start,
                volume: 1
            ))
        }
        return inputs
    }

    private func export(_ request: ExportRequest) async throws {
        let composition = AVMutableComposition()
        var mixParameters: [AVMutableAudioMixInputParameters] = []

        for input in request.inputs {
            let asset = AVURLAsset(url: input.url)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            let duration = try await asset.load(.duration)
            let sourceDuration = CMTimeSubtract(duration, input.sourceStart)
            guard tracks.indices.contains(input.trackIndex),
                  CMTimeCompare(sourceDuration, .zero) > 0,
                  let compositionTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                  ) else {
                continue
            }
            let sourceTrack = tracks[input.trackIndex]
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: input.sourceStart, duration: sourceDuration),
                of: sourceTrack,
                at: .zero
            )
            let parameters = AVMutableAudioMixInputParameters(track: compositionTrack)
            parameters.setVolume(input.volume, at: .zero)
            mixParameters.append(parameters)
        }

        guard !composition.tracks(withMediaType: .audio).isEmpty,
              let exporter = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetAppleM4A
              ) else {
            throw RecorderError.speechUnavailable
        }

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = mixParameters
        exporter.audioMix = audioMix
        try await exporter.export(to: request.outputURL, as: .m4a)
    }

    private func temporaryAudioURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlitzRecorderTranscription", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
    }
}
