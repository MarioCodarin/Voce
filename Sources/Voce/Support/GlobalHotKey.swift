import AppKit
import Carbon.HIToolbox
import VoceKit

/// A system-wide shortcut that opens the file picker from any app.
/// Carbon's RegisterEventHotKey is still the smallest way to do this without an
/// accessibility permission prompt; the handler only posts an in-process notification.
@MainActor
final class GlobalHotKey {
    static let pressed = Notification.Name("com.mariocodarin.voce.globalShortcutPressed")

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func apply(_ shortcut: GlobalShortcut) {
        unregister()
        guard let keyCode = shortcut.keyCode, let modifiers = shortcut.modifiers else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handler: EventHandlerUPP = { _, _, _ in
            NotificationCenter.default.post(name: GlobalHotKey.pressed, object: nil)
            return noErr
        }
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &handlerRef
        )
        guard installStatus == noErr else {
            Log.warning(.app, "global shortcut handler install failed status=\(installStatus)")
            handlerRef = nil
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x564F4345), id: 1)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            Log.warning(.app, "global shortcut registration failed status=\(status)")
            if let handlerRef { RemoveEventHandler(handlerRef) }
            handlerRef = nil
            hotKeyRef = nil
            return
        }
        Log.info(.app, "global shortcut registered \(shortcut.rawValue)")
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
