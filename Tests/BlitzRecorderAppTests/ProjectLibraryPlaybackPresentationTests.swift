import CoreGraphics
import XCTest
@testable import BlitzRecorderApp

final class ProjectLibraryPlaybackPresentationTests: XCTestCase {
    func testProjectLibraryUsesEditingAndMediaLanguage() {
        XCTAssertEqual(ProjectLibrarySymbols.editRecording, "scissors")
        XCTAssertEqual(ProjectLibraryDetailTab.media.title, "Media")
        XCTAssertEqual(ProjectLibraryDetailTab.media.systemImage, "film.stack")
    }

    func testPortraitVideoUsesPortraitSurface() {
        let layout = ProjectLibraryPlayerSizing.layout(.init(
            contentSize: CGSize(width: 1080, height: 1920),
            maximumSize: CGSize(width: 720, height: 420)
        ))

        XCTAssertEqual(layout.videoSize.width, 236.25, accuracy: 0.001)
        XCTAssertEqual(layout.videoSize.height, 420, accuracy: 0.001)
        XCTAssertEqual(layout.transportWidth, 720, accuracy: 0.001)
    }

    func testLandscapeVideoUsesLandscapeSurface() {
        let layout = ProjectLibraryPlayerSizing.layout(.init(
            contentSize: CGSize(width: 1920, height: 1080),
            maximumSize: CGSize(width: 720, height: 420)
        ))

        XCTAssertEqual(layout.videoSize.width, 720, accuracy: 0.001)
        XCTAssertEqual(layout.videoSize.height, 405, accuracy: 0.001)
        XCTAssertEqual(layout.transportWidth, 720, accuracy: 0.001)
    }

    func testDetailTabChangeDoesNotReloadCurrentProject() {
        let shouldReload = ProjectLibraryPlaybackReloadPolicy.shouldReload(.init(
            selectedProjectPath: "/recordings/project.json",
            loadedProjectPath: "/recordings/project.json",
            hasActivePlayback: true
        ))

        XCTAssertFalse(shouldReload)
    }

    func testProjectChangeReloadsPlayback() {
        let shouldReload = ProjectLibraryPlaybackReloadPolicy.shouldReload(.init(
            selectedProjectPath: "/recordings/new/project.json",
            loadedProjectPath: "/recordings/old/project.json",
            hasActivePlayback: true
        ))

        XCTAssertTrue(shouldReload)
    }
}
