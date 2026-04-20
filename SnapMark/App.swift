import Cocoa
import OSLog

private let appLogger = Logger(subsystem: "com.snapmark.app", category: "app")

@main
final class SnapMarkMain {
    private static let appDelegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = appDelegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: GlobalHotkeyManager!
    private var captureCoordinator: CaptureCoordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        appLogger.info("Application did finish launching. bundlePath=\(Bundle.main.bundlePath, privacy: .public) bundleId=\(Bundle.main.bundleIdentifier ?? "nil", privacy: .public)")

        ProcessInfo.processInfo.disableAutomaticTermination("SnapMark stays active as a menu bar capture utility")
        ProcessInfo.processInfo.disableSuddenTermination()

        setupMenuBar()

        captureCoordinator = CaptureCoordinator()
        hotkeyManager = GlobalHotkeyManager {
            self.startCapture()
        }
        hotkeyManager.register()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        appLogger.info("Application will terminate")
    }

    func showForegroundWindows() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func showMenuBarOnly() {
        NSApp.activate(ignoringOtherApps: false)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "SnapMark")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Region (⌃⇧A)", action: #selector(startCapture), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit SnapMark", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc func startCapture() {
        appLogger.info("Capture requested")
        captureCoordinator.beginCapture()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
