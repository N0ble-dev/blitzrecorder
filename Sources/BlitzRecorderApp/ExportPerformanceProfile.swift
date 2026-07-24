import Foundation

enum ExportPerformancePreset: String, CaseIterable {
    case fast
    case balanced
    case maximum
    case custom

    var displayName: String {
        switch self {
        case .fast:
            "Fast"
        case .balanced:
            "Balanced"
        case .maximum:
            "Maximum"
        case .custom:
            "Custom"
        }
    }
}

struct ExportPerformanceProfile: Equatable {
    let preset: ExportPerformancePreset
    let resolution: OutputResolution
    let framesPerSecond: Int
    let videoQuality: ExportVideoQuality

    static func resolved(
        preset: ExportPerformancePreset,
        sourceResolution: OutputResolution,
        sourceFramesPerSecond: Int,
        customResolution: OutputResolution,
        customFramesPerSecond: Int,
        customVideoQuality: ExportVideoQuality
    ) -> ExportPerformanceProfile {
        let sourceFPS = normalizedFramesPerSecond(sourceFramesPerSecond)
        switch preset {
        case .fast:
            return ExportPerformanceProfile(
                preset: preset,
                resolution: .p1080,
                framesPerSecond: min(30, sourceFPS),
                videoQuality: .standard
            )
        case .balanced:
            return ExportPerformanceProfile(
                preset: preset,
                resolution: .p1080,
                framesPerSecond: sourceFPS,
                videoQuality: .high
            )
        case .maximum:
            return ExportPerformanceProfile(
                preset: preset,
                resolution: sourceResolution,
                framesPerSecond: sourceFPS,
                videoQuality: .maximum
            )
        case .custom:
            return ExportPerformanceProfile(
                preset: preset,
                resolution: customResolution,
                framesPerSecond: normalizedFramesPerSecond(customFramesPerSecond),
                videoQuality: customVideoQuality
            )
        }
    }

    func applying(to settings: RecordingSettings) -> RecordingSettings {
        var settings = settings
        settings.outputResolution = resolution
        settings.framesPerSecond = framesPerSecond
        settings.customVideoBitrate = videoQuality.videoBitrate(
            baseBitrate: settings.autoVideoBitrate
        )
        if reducesExpensiveEffects {
            settings.screenShadowEnabled = false
            settings.cameraShadowEnabled = false
        }
        return settings
    }

    func applying(to scene: RecordingScene) -> RecordingScene {
        guard reducesExpensiveEffects else { return scene }
        var scene = scene
        scene.screenShadowEnabled = false
        scene.cameraShadowEnabled = false
        return scene
    }

    var reducesExpensiveEffects: Bool {
        preset == .fast
    }

    private static func normalizedFramesPerSecond(_ value: Int) -> Int {
        value <= 30 ? 30 : 60
    }
}
