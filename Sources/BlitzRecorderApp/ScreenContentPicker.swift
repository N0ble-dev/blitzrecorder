import Foundation
import ScreenCaptureKit

enum ScreenContentPickerPresentationMode {
    case newSelection
    case updateActiveStream

    static func resolve(hasActiveStream: Bool) -> Self {
        hasActiveStream ? .updateActiveStream : .newSelection
    }
}

@MainActor
final class ScreenContentPicker: NSObject, @preconcurrency SCContentSharingPickerObserver {
    private var continuation: CheckedContinuation<SCContentFilter, Error>?

    func pick(for activeStream: SCStream? = nil) async throws -> SCContentFilter {
        guard continuation == nil else {
            throw RecorderError.screenSelectionInProgress
        }
        guard #available(macOS 14.0, *) else {
            throw RecorderError.screenCapturePermissionRequired
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let picker = SCContentSharingPicker.shared
            var configuration = SCContentSharingPickerConfiguration()
            configuration.allowedPickerModes = [.singleDisplay, .singleWindow]
            configuration.excludedBundleIDs = [Bundle.main.bundleIdentifier].compactMap { $0 }
            configuration.allowsChangingSelectedContent = true

            picker.configuration = configuration
            picker.maximumStreamCount = 1
            picker.isActive = true
            picker.add(self)
            switch ScreenContentPickerPresentationMode.resolve(hasActiveStream: activeStream != nil) {
            case .newSelection:
                picker.present()
            case .updateActiveStream:
                guard let activeStream else {
                    picker.present()
                    return
                }
                picker.setConfiguration(configuration, for: activeStream)
                picker.present(for: activeStream)
            }
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        finish(picker: picker, result: .failure(RecorderError.screenSelectionCancelled))
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        finish(picker: picker, result: .success(filter))
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        finish(picker: SCContentSharingPicker.shared, result: .failure(error))
    }

    private func finish(picker: SCContentSharingPicker, result: Result<SCContentFilter, Error>) {
        picker.remove(self)
        picker.isActive = false

        guard let continuation else { return }
        self.continuation = nil

        switch result {
        case .success(let filter):
            continuation.resume(returning: filter)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
