import Cocoa
import OSLog

private let captureLogger = Logger(subsystem: "com.snapmark.app", category: "capture")

/// Coordinates the capture flow: shows selection overlay → captures → opens editor.
class CaptureCoordinator: NSObject, NSWindowDelegate {
    private var selectionWindows: [RegionSelectorWindow] = []
    private var retiringSelectionWindows: [RegionSelectorWindow] = []
    private var editorWindowController: NSWindowController?

    func beginCapture() {
        captureLogger.info("beginCapture invoked")

        guard ensureCapturePermission() else {
            captureLogger.info("beginCapture aborted because permission check failed")
            return
        }

        // Close any existing selection overlays
        selectionWindows.forEach { $0.close() }
        selectionWindows.removeAll()

        (NSApp.delegate as? AppDelegate)?.showForegroundWindows()

        // Create a fullscreen transparent overlay on each screen
        for screen in NSScreen.screens {
            captureLogger.info("Creating selector window for screen frame=\(String(describing: screen.frame), privacy: .public)")
            let window = RegionSelectorWindow(screen: screen) { [weak self] selectedRect, selectorWindowID in
                self?.handleSelectionComplete(rect: selectedRect, selectorWindowID: selectorWindowID)
            } onCancel: { [weak self] in
                self?.cancelCapture()
            }
            selectionWindows.append(window)
            window.makeKeyAndOrderFront(nil)
        }

        selectionWindows.first?.makeKey()
        captureLogger.info("Selection overlay presented on \(self.selectionWindows.count) screen(s)")
    }

    private func handleSelectionComplete(rect: CGRect, selectorWindowID: CGWindowID) {
        captureLogger.info("Selection completed rect=\(String(describing: rect), privacy: .public)")

        retireSelectionWindows()

        // Convert from bottom-left (AppKit) to top-left (CG) coordinates
        let mainScreenHeight = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
        let captureRect = CGRect(
            x: rect.origin.x,
            y: mainScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        captureLogger.info("Converted capture rect=\(String(describing: captureRect), privacy: .public)")

        guard let image = ScreenCapture.capture(rect: captureRect, belowWindow: selectorWindowID) else {
            captureLogger.error("ScreenCapture.capture returned nil")
            ScreenCapture.showCaptureFailedAlert()
            return
        }

        captureLogger.info("Capture returned image size=\(String(describing: image.size), privacy: .public)")

        openAnnotationEditor(with: image, capturedRect: rect)
    }

    private func cancelCapture() {
        captureLogger.info("Capture cancelled")
        retireSelectionWindows()
        if editorWindowController == nil {
            (NSApp.delegate as? AppDelegate)?.showMenuBarOnly()
        }
    }

    private func retireSelectionWindows() {
        guard !selectionWindows.isEmpty else { return }

        let windows = selectionWindows
        selectionWindows.removeAll()
        retiringSelectionWindows.append(contentsOf: windows)

        for window in windows {
            window.orderOut(nil)
            window.ignoresMouseEvents = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            windows.forEach { $0.close() }
            self.retiringSelectionWindows.removeAll { retiredWindow in
                windows.contains { $0 === retiredWindow }
            }
        }
    }

    private func ensureCapturePermission() -> Bool {
        let hasPermission = ScreenCapture.hasPermission()
        captureLogger.info("Screen capture preflight permission=\(hasPermission)")
        if hasPermission {
            return true
        }

        let requested = ScreenCapture.requestPermissionIfNeeded()
        captureLogger.info("Screen capture requestPermission result=\(requested)")

        if requested {
            ScreenCapture.showPermissionAlert(requiresRelaunch: true)
        } else if ScreenCapture.hasRequestedPermissionThisSession() {
            ScreenCapture.showPermissionPendingAlert()
        }

        return false
    }

    private func openAnnotationEditor(with image: NSImage, capturedRect: CGRect) {
        DispatchQueue.main.async {
            captureLogger.info("Opening annotation editor for rect=\(String(describing: capturedRect), privacy: .public)")
            let editorVC = AnnotationEditorViewController(image: image)

            let contentSize = AnnotationEditorLayoutRules.contentSize(for: image.size)
            let contentRect = NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)

            let window = NSWindow(
                contentRect: contentRect,
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "SnapMark — Annotate"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.minSize = AnnotationEditorLayoutRules.minimumWindowSize
            window.contentViewController = editorVC
            self.editorWindowController = NSWindowController(window: window)

            (NSApp.delegate as? AppDelegate)?.showForegroundWindows()
            window.center()
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)

            captureLogger.info("Annotation editor window displayed")
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == editorWindowController?.window else {
            return
        }

        captureLogger.info("Annotation editor window will close")
        editorWindowController = nil
        (NSApp.delegate as? AppDelegate)?.showMenuBarOnly()
    }
}
