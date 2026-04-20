import Cocoa

/// The main annotation editor — displays the captured image and lets the user draw on it.
class AnnotationEditorViewController: NSViewController {
    private let capturedImage: NSImage
    private var canvasView: AnnotationCanvasView!
    private var toolbarView: AnnotationToolbarView!

    init(image: NSImage) {
        self.capturedImage = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func loadView() {
        let layoutSize = AnnotationEditorLayoutRules.contentSize(for: capturedImage.size)
        let canvasHeight = AnnotationEditorLayoutRules.canvasHeight(for: capturedImage.size)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: layoutSize.width, height: layoutSize.height))

        // Canvas
        canvasView = AnnotationCanvasView(
            frame: NSRect(x: 0, y: 0, width: layoutSize.width, height: canvasHeight),
            image: capturedImage
        )

        // Toolbar at top
        toolbarView = AnnotationToolbarView(
            frame: NSRect(x: 0, y: canvasHeight, width: layoutSize.width, height: AnnotationEditorLayoutRules.toolbarHeight),
            canvasView: canvasView
        )

        container.addSubview(canvasView)
        container.addSubview(toolbarView)

        // Autoresizing
        canvasView.autoresizingMask = [.width, .height]
        toolbarView.autoresizingMask = [.width, .minYMargin]

        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Keyboard shortcuts via menu items
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyDown(event) ?? event
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard view.window?.isKeyWindow == true else { return event }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.isEmpty && (event.keyCode == 51 || event.keyCode == 117) { // Delete / Forward Delete
            canvasView.removeLastAnnotation()
            return nil
        }

        // Cmd+C — copy to clipboard
        if flags == .command && event.keyCode == 8 { // 'c'
            copyToClipboard()
            return nil
        }

        // Cmd+S — save to file
        if flags == .command && event.keyCode == 1 { // 's'
            saveToFile()
            return nil
        }

        // Cmd+Z — undo
        if flags == .command && event.keyCode == 6 { // 'z'
            canvasView.undo()
            return nil
        }

        return event
    }

    private func copyToClipboard() {
        guard let image = canvasView.renderFinalImage() else { return }
        ClipboardManager.copy(image: image)

        // Brief flash feedback
        showToast("Copied to clipboard!")
    }

    private func saveToFile() {
        guard let image = canvasView.renderFinalImage() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "SnapMark_\(Self.timestamp()).png"

        panel.beginSheetModal(for: view.window!) { response in
            if response == .OK, let url = panel.url {
                FileSaver.save(image: image, to: url)
                self.showToast("Saved!")
            }
        }
    }

    private func showToast(_ message: String) {
        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.75)
        label.isBezeled = false
        label.drawsBackground = true
        label.alignment = .center
        label.sizeToFit()
        label.frame.size.width += 20
        label.frame.size.height += 8
        label.frame.origin = NSPoint(
            x: view.bounds.midX - label.frame.width / 2,
            y: view.bounds.midY - label.frame.height / 2
        )
        label.wantsLayer = true
        label.layer?.cornerRadius = 6

        view.addSubview(label)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                label.animator().alphaValue = 0
            }, completionHandler: {
                label.removeFromSuperview()
            })
        }
    }

    private static func timestamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd_HHmmss"
        return fmt.string(from: Date())
    }
}
