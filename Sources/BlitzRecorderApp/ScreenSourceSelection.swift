import Foundation
import ScreenCaptureKit

struct ScreenSourceSelectionSnapshot: Equatable {
    let usesPickedContent: Bool
    let binding: ScreenSourceBinding?
    let selectedDisplayID: String?
    let crop: CGRect?
}

struct ScreenSourceSelectionResult {
    let settings: RecordingSettings
    let changed: Bool
}

@MainActor
final class ScreenSourceSelection {
    struct DisplayRequest {
        let id: String?
        let settings: RecordingSettings
    }

    struct BindingRequest {
        let binding: ScreenSourceBinding
        let settings: RecordingSettings
    }

    struct PickedContentRequest {
        let filter: SCContentFilter
        let persistentBinding: ScreenSourceBinding?
        let settings: RecordingSettings
    }

    struct ReconciliationRequest {
        let settings: RecordingSettings
        let hasPersistentAccess: Bool
    }

    struct RestoreRequest {
        let snapshot: ScreenSourceSelectionSnapshot
        let settings: RecordingSettings
    }

    private(set) var pickedContentFilter: SCContentFilter?

    var hasActivePickedContent: Bool {
        pickedContentFilter != nil
    }

    func selectDisplay(_ request: DisplayRequest) -> RecordingSettings {
        var settings = request.settings
        settings.selectedDisplayID = request.id
        settings.screenSourceBinding = .display(id: request.id)
        settings.usesPickedScreenContent = false
        settings.screenCrop = nil
        pickedContentFilter = nil
        return settings
    }

    func selectBinding(_ request: BindingRequest) -> RecordingSettings {
        var settings = request.settings
        settings.screenSourceBinding = request.binding
        if request.binding.kind == .display {
            settings.selectedDisplayID = request.binding.displayID
        }
        settings.usesPickedScreenContent = false
        settings.screenCrop = nil
        pickedContentFilter = nil
        return settings
    }

    func selectPickedContent(_ request: PickedContentRequest) -> RecordingSettings {
        var settings = request.settings
        if let binding = request.persistentBinding {
            settings.screenSourceBinding = binding
            if binding.kind == .display {
                settings.selectedDisplayID = binding.displayID
            }
        }
        settings.usesPickedScreenContent = true
        settings.screenCrop = nil
        pickedContentFilter = request.filter
        return settings
    }

    func clearPickedContent(in currentSettings: RecordingSettings) -> RecordingSettings {
        var settings = currentSettings
        settings.usesPickedScreenContent = false
        pickedContentFilter = nil
        return settings
    }

    func markPickedContentActive(in currentSettings: RecordingSettings) -> RecordingSettings {
        guard pickedContentFilter != nil else { return currentSettings }
        var settings = currentSettings
        settings.usesPickedScreenContent = true
        settings.screenCrop = nil
        return settings
    }

    func reconcile(_ request: ReconciliationRequest) -> ScreenSourceSelectionResult {
        ScreenSourceSelectionResult(settings: request.settings, changed: false)
    }

    func snapshot(from settings: RecordingSettings) -> ScreenSourceSelectionSnapshot {
        ScreenSourceSelectionSnapshot(
            usesPickedContent: settings.usesPickedScreenContent,
            binding: settings.screenSourceBinding,
            selectedDisplayID: settings.selectedDisplayID,
            crop: settings.screenCrop
        )
    }

    func restore(_ request: RestoreRequest) -> RecordingSettings {
        var settings = request.settings
        settings.selectedDisplayID = request.snapshot.selectedDisplayID
        settings.screenSourceBinding = request.snapshot.binding
        settings.usesPickedScreenContent = pickedContentFilter != nil && request.snapshot.usesPickedContent
        settings.screenCrop = request.snapshot.binding?.kind == .display ? request.snapshot.crop : nil
        return settings
    }

    func activeFilter(for settings: RecordingSettings) -> SCContentFilter? {
        settings.usesPickedScreenContent ? pickedContentFilter : nil
    }
}
