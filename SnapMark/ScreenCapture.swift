import Cocoa
import OSLog

private let screenCaptureLogger = Logger(subsystem: "com.snapmark.app", category: "screen-capture")

/// Captures a region of the screen as an NSImage using Core Graphics.
class ScreenCapture {
    private static var didRequestPermissionThisSession = false

    static func hasPermission() -> Bool {
        let result = CGPreflightScreenCaptureAccess()
        screenCaptureLogger.info("CGPreflightScreenCaptureAccess=\(result)")
        return result
    }

    static func requestPermissionIfNeeded() -> Bool {
        guard !didRequestPermissionThisSession else {
            screenCaptureLogger.info("Skipping duplicate screen capture permission request in the same session")
            return false
        }

        didRequestPermissionThisSession = true
        let result = CGRequestScreenCaptureAccess()
        screenCaptureLogger.info("CGRequestScreenCaptureAccess=\(result)")
        return result
    }

    static func hasRequestedPermissionThisSession() -> Bool {
        didRequestPermissionThisSession
    }

    /// Capture the given screen rect (in global screen coordinates).
    static func capture(rect: CGRect, belowWindow windowID: CGWindowID? = nil) -> NSImage? {
        guard rect.width > 0, rect.height > 0 else {
            screenCaptureLogger.error("Rejecting capture because rect is empty: \(String(describing: rect), privacy: .public)")
            return nil
        }

        let listOption: CGWindowListOption = windowID == nil ? .optionOnScreenOnly : .optionOnScreenBelowWindow
        let relativeWindow = windowID ?? kCGNullWindowID

        screenCaptureLogger.info("Attempting capture rect=\(String(describing: rect), privacy: .public) relativeWindow=\(relativeWindow)")
        guard let cgImage = CGWindowListCreateImage(
            rect,
            listOption,
            relativeWindow,
            [.bestResolution]
        ) else {
            screenCaptureLogger.error("CGWindowListCreateImage returned nil")
            return nil
        }
        screenCaptureLogger.info("CGWindowListCreateImage succeeded width=\(cgImage.width) height=\(cgImage.height)")
        return NSImage(cgImage: cgImage, size: rect.size)
    }

    /// Capture the entire main screen.
    static func captureFullScreen() -> NSImage? {
        guard let screen = NSScreen.main else { return nil }
        return capture(rect: screen.frame)
    }

    static func showPermissionAlert(requiresRelaunch: Bool) {
        screenCaptureLogger.info("Showing permission alert requiresRelaunch=\(requiresRelaunch)")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = requiresRelaunch
            ? "Screen Recording permission was granted"
            : "Screen Recording permission is required"
        alert.informativeText = requiresRelaunch
            ? "macOS usually requires the app to relaunch before screen capture starts working. Quit and reopen SnapMark, then try capture again."
            : "Allow SnapMark in System Settings > Privacy & Security > Screen Recording, then reopen the app and try again."
        alert.addButton(withTitle: requiresRelaunch ? "Relaunch SnapMark" : "OK")
        if requiresRelaunch {
            alert.addButton(withTitle: "Later")
        }

        let response = alert.runModal()
        if requiresRelaunch, response == .alertFirstButtonReturn {
            relaunchApp()
        }
    }

    static func showPermissionPendingAlert() {
        screenCaptureLogger.info("Showing permission pending alert")
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Finish granting Screen Recording"
        alert.informativeText = "Enable SnapMark in System Settings > Privacy & Security > Screen & System Audio Recording, then quit and reopen the app before trying capture again."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    static func showCaptureFailedAlert() {
        screenCaptureLogger.error("Showing capture failed alert")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Capture failed"
        alert.informativeText = "SnapMark could not read the selected screen region. If you just granted Screen Recording permission, relaunch the app and try again."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func relaunchApp() {
        screenCaptureLogger.info("Relaunching app after permission grant")
        let appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            NSApp.terminate(nil)
        }
    }
}
