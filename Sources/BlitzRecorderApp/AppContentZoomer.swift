import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum AppContentZoomDirection {
    case zoomIn
    case zoomOut
    case reset

    var messageVerb: String {
        switch self {
        case .zoomIn:
            return "Made larger"
        case .zoomOut:
            return "Made smaller"
        case .reset:
            return "Reset"
        }
    }
}

struct AppContentZoomShortcut: Equatable {
    let character: String

    static func shortcut(for direction: AppContentZoomDirection) -> AppContentZoomShortcut {
        switch direction {
        case .zoomIn:
            return AppContentZoomShortcut(character: "+")
        case .zoomOut:
            return AppContentZoomShortcut(character: "-")
        case .reset:
            return AppContentZoomShortcut(character: "0")
        }
    }
}

struct ResolvedAppContentZoomShortcut: Equatable {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
}

enum AppContentZoomShortcutResolver {
    private struct KeyboardLayoutData {
        let data: CFData

        var layout: UnsafePointer<UCKeyboardLayout>? {
            guard let bytes = CFDataGetBytePtr(data) else { return nil }
            return bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 }
        }
    }

    private struct ModifierCandidate {
        let carbonState: UInt32
        let eventFlags: CGEventFlags
    }

    private struct TranslationRequest {
        let keyCode: CGKeyCode
        let carbonModifierState: UInt32
        let keyboardLayout: KeyboardLayoutData
    }

    static func resolve(_ shortcut: AppContentZoomShortcut) -> ResolvedAppContentZoomShortcut? {
        guard let layout = currentKeyboardLayout() else {
            return fallback(shortcut)
        }

        for keyCode in CGKeyCode(0)..<CGKeyCode(65) {
            for modifier in modifierCandidates {
                let character = translatedCharacter(TranslationRequest(
                    keyCode: keyCode,
                    carbonModifierState: modifier.carbonState,
                    keyboardLayout: layout
                ))
                if character == shortcut.character {
                    return ResolvedAppContentZoomShortcut(
                        keyCode: keyCode,
                        flags: modifier.eventFlags
                    )
                }
            }
        }
        return fallback(shortcut)
    }

    static func translatedCharacter(_ shortcut: ResolvedAppContentZoomShortcut) -> String? {
        guard let layout = currentKeyboardLayout() else { return nil }
        let carbonState = carbonModifierState(for: shortcut.flags)
        return translatedCharacter(TranslationRequest(
            keyCode: shortcut.keyCode,
            carbonModifierState: carbonState,
            keyboardLayout: layout
        ))
    }

    private static let modifierCandidates: [ModifierCandidate] = [
        ModifierCandidate(carbonState: 0, eventFlags: []),
        ModifierCandidate(
            carbonState: UInt32(shiftKey) >> 8,
            eventFlags: .maskShift
        ),
        ModifierCandidate(
            carbonState: UInt32(optionKey) >> 8,
            eventFlags: .maskAlternate
        ),
        ModifierCandidate(
            carbonState: UInt32(shiftKey | optionKey) >> 8,
            eventFlags: [.maskShift, .maskAlternate]
        )
    ]

    private static func currentKeyboardLayout() -> KeyboardLayoutData? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawData = TISGetInputSourceProperty(
                inputSource,
                kTISPropertyUnicodeKeyLayoutData
              ) else {
            return nil
        }
        let data = unsafeBitCast(rawData, to: CFData.self)
        return KeyboardLayoutData(data: data)
    }

    private static func translatedCharacter(_ request: TranslationRequest) -> String? {
        guard let layout = request.keyboardLayout.layout else { return nil }
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
            layout,
            UInt16(request.keyCode),
            UInt16(kUCKeyActionDown),
            request.carbonModifierState,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )
        guard status == noErr else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }

    private static func carbonModifierState(for flags: CGEventFlags) -> UInt32 {
        var state: UInt32 = 0
        if flags.contains(.maskShift) {
            state |= UInt32(shiftKey) >> 8
        }
        if flags.contains(.maskAlternate) {
            state |= UInt32(optionKey) >> 8
        }
        return state
    }

    private static func fallback(
        _ shortcut: AppContentZoomShortcut
    ) -> ResolvedAppContentZoomShortcut? {
        switch shortcut.character {
        case "+":
            return ResolvedAppContentZoomShortcut(keyCode: 24, flags: .maskShift)
        case "-":
            return ResolvedAppContentZoomShortcut(keyCode: 27, flags: [])
        case "0":
            return ResolvedAppContentZoomShortcut(keyCode: 29, flags: [])
        default:
            return nil
        }
    }
}

enum AppContentZoomTargetResolver {
    static func processID(
        settings: RecordingSettings,
        pickedWindowProcessID: () async -> pid_t?,
        applicationProcessID: (ScreenSourceBinding) -> pid_t?,
        windowProcessID: (ScreenSourceBinding) async -> pid_t?,
        frontWindowProcessID: (String?) -> pid_t?
    ) async -> pid_t? {
        if settings.usesPickedScreenContent {
            if let processID = await pickedWindowProcessID() {
                return processID
            }
            guard settings.screenSourceBinding?.kind != .application,
                  settings.screenSourceBinding?.kind != .window else {
                return nil
            }
        }

        guard let binding = settings.screenSourceBinding else {
            return frontWindowProcessID(settings.selectedDisplayID)
        }

        switch binding.kind {
        case .application:
            return applicationProcessID(binding)
        case .window:
            return await windowProcessID(binding)
        case .display:
            return frontWindowProcessID(binding.displayID ?? settings.selectedDisplayID)
        }
    }
}

enum AppContentZoomer {
    struct Request {
        let direction: AppContentZoomDirection
        let processID: pid_t
    }

    private struct PostRequest {
        let shortcut: ResolvedAppContentZoomShortcut
        let processID: pid_t
        let keyDown: Bool
    }

    @discardableResult
    static func apply(_ request: Request) -> Bool {
        let shortcut = AppContentZoomShortcut.shortcut(for: request.direction)
        guard let resolvedShortcut = AppContentZoomShortcutResolver.resolve(shortcut) else {
            return false
        }
        let keyDownPosted = post(PostRequest(
            shortcut: resolvedShortcut,
            processID: request.processID,
            keyDown: true
        ))
        let keyUpPosted = post(PostRequest(
            shortcut: resolvedShortcut,
            processID: request.processID,
            keyDown: false
        ))
        return keyDownPosted && keyUpPosted
    }

    private static func post(_ request: PostRequest) -> Bool {
        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: request.shortcut.keyCode,
            keyDown: request.keyDown
        ) else {
            return false
        }
        event.flags = request.shortcut.flags.union(.maskCommand)
        event.postToPid(request.processID)
        return true
    }
}
