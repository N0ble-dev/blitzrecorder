import Foundation
import XCTest
@testable import BlitzRecorderApp

final class ProjectRenameTests: XCTestCase {
    func testRenamePersistsProjectTitleAndHistory() throws {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: outputDirectory)
        }

        var settings = RecordingSettings()
        settings.outputDirectory = outputDirectory
        settings.savesSourceFiles = true

        let store = TakeFileStore()
        let take = try store.createTake(settings: settings)
        let renamed = try store.renameProject(RecordingProjectRenameRequest(
            projectURL: take.projectURL,
            title: "  Client launch walkthrough  ",
            settings: settings
        ))

        let reloaded = try store.loadRecordingProject(at: take.projectURL)
        let history = store.loadProjectHistory(settings: settings)

        XCTAssertEqual(renamed.title, "Client launch walkthrough")
        XCTAssertEqual(reloaded.title, "Client launch walkthrough")
        XCTAssertEqual(history.entries.first?.title, "Client launch walkthrough")
        XCTAssertEqual(history.entries.first?.id, renamed.id)
    }
}
