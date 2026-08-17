import AppKit
import Carbon

@MainActor
final class HotkeyManager {
    struct Hotkey {
        var keyCode: UInt32
        var carbonModifiers: UInt32
    }

    static let defaultHotkey = Hotkey(keyCode: 49, carbonModifiers: UInt32(cmdKey | shiftKey))

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?

    func register(_ hotkey: Hotkey, handler: @escaping () -> Void) {
        self.handler = handler

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if hotKeyID.id == 1 {
                    manager.handler?()
                }
                return noErr
            },
            1,
            &eventSpec,
            selfPtr,
            nil
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D424454), id: 1)
        RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}
