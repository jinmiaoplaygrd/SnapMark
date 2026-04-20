import Cocoa
import Carbon.HIToolbox

/// Registers a global keyboard shortcut (Ctrl+Shift+A) using Carbon Event APIs.
/// This works even when the app is not focused.
class GlobalHotkeyManager {
    private var eventHandler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func register() {
        // Ctrl+Shift+A
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x534D4B59) // "SMKY"
        hotKeyID.id = 1

        var hotKeyRef: EventHotKeyRef?

        // kVK_ANSI_A = 0x00, cmdKey=256, shiftKey=512, optionKey=2048, controlKey=4096
        let modifiers: UInt32 = UInt32(controlKey | shiftKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_A)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Store self pointer for the C callback
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, refcon) -> OSStatus in
                guard let refcon = refcon else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.action()
                }
                return noErr
            },
            1,
            &eventType,
            refcon,
            &eventHandler
        )

        if status != noErr {
            print("⚠️ Failed to install event handler: \(status)")
            return
        }

        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regStatus != noErr {
            print("⚠️ Failed to register hotkey: \(regStatus)")
        } else {
            print("✅ Global hotkey Ctrl+Shift+A registered")
        }
    }
}
