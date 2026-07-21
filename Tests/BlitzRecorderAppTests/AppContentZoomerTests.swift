import XCTest
@testable import BlitzRecorderApp

final class AppContentZoomerTests: XCTestCase {
    func testShortcutsUseCharactersInsteadOfKeyboardLayoutKeyCodes() {
        XCTAssertEqual(
            AppContentZoomShortcut.shortcut(for: .zoomIn),
            AppContentZoomShortcut(character: "+")
        )
        XCTAssertEqual(
            AppContentZoomShortcut.shortcut(for: .zoomOut),
            AppContentZoomShortcut(character: "-")
        )
        XCTAssertEqual(
            AppContentZoomShortcut.shortcut(for: .reset),
            AppContentZoomShortcut(character: "0")
        )
    }

    func testShortcutsResolveOnTheCurrentKeyboardLayout() throws {
        for direction in [
            AppContentZoomDirection.zoomIn,
            AppContentZoomDirection.zoomOut,
            AppContentZoomDirection.reset
        ] {
            let shortcut = AppContentZoomShortcut.shortcut(for: direction)
            let resolved = try XCTUnwrap(AppContentZoomShortcutResolver.resolve(shortcut))

            XCTAssertEqual(
                AppContentZoomShortcutResolver.translatedCharacter(resolved),
                shortcut.character
            )
        }
    }
}
