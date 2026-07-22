import XCTest
@testable import BlitzRecorderApp

@MainActor
final class RecorderViewModelWindowFitTests: XCTestCase {
    func testWindowCloseCancelsScheduledTargetWindowFit() {
        let suiteName = "RecorderViewModelWindowFitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = RecordingSettings()
        settings.enabledSources = [.screen]
        settings.screenSourceBinding = .display(id: "display-1")
        RecordingSettingsStore.save(settings, defaults: defaults)

        let viewModel = RecorderViewModel(
            coordinator: RecorderCoordinator(
                accessController: AccessController(defaults: defaults),
                defaults: defaults
            ),
            previewStage: PreviewStageView()
        )

        viewModel.setTargetWindowZoom(0.5)
        XCTAssertTrue(viewModel.hasScheduledTargetWindowFit)

        viewModel.prepareForWindowClose()

        XCTAssertFalse(viewModel.hasScheduledTargetWindowFit)
    }

    func testWindowZoomCanMakeSourceWindowWiderThanCanvasSlot() {
        let suiteName = "RecorderViewModelWindowFitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var settings = RecordingSettings()
        settings.enabledSources = [.screen]
        settings.screenSourceBinding = ScreenSourceBinding(
            kind: .application,
            displayID: nil,
            bundleIdentifier: "com.google.Chrome",
            applicationName: "Google Chrome",
            processID: nil,
            windowID: nil,
            windowTitle: nil
        )
        RecordingSettingsStore.save(settings, defaults: defaults)

        let viewModel = RecorderViewModel(
            coordinator: RecorderCoordinator(
                accessController: AccessController(defaults: defaults),
                defaults: defaults
            ),
            previewStage: PreviewStageView()
        )

        viewModel.setTargetWindowZoom(0.5)

        XCTAssertEqual(viewModel.targetWindowZoom, 0.5)
        XCTAssertEqual(
            RecordingSettingsStore.load(defaults: defaults).screenWindowZoom,
            0.5
        )
    }
}
