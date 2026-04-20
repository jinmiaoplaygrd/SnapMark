import Cocoa

/// A transparent full-screen window that lets the user drag to select a region.
class RegionSelectorWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(screen: NSScreen, onSelection: @escaping (CGRect, CGWindowID) -> Void, onCancel: @escaping () -> Void) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: false)
        isReleasedWhenClosed = false
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let selectorView = RegionSelectorView(
            frame: CGRect(origin: .zero, size: screen.frame.size),
            onSelection: onSelection,
            onCancel: onCancel
        )
        selectorView.autoresizingMask = [.width, .height]
        self.contentView = selectorView
        self.initialFirstResponder = selectorView
    }
}

/// The view that handles mouse drag for region selection.
class RegionSelectorView: NSView {
    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero
    private let onSelection: (CGRect, CGWindowID) -> Void
    private let onCancel: () -> Void
    private var trackingArea: NSTrackingArea?

    init(frame: NSRect, onSelection: @escaping (CGRect, CGWindowID) -> Void, onCancel: @escaping () -> Void) {
        self.onSelection = onSelection
        self.onCancel = onCancel
        super.init(frame: frame)
        setupCrosshairCursor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    private func setupCrosshairCursor() {
        NSCursor.crosshair.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)

        currentRect = NSRect(x: x, y: y, width: w, height: h)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard currentRect.width > 5 && currentRect.height > 5 else {
            // Too small — treat as cancel
            cancelSelection()
            return
        }

        // Convert to screen coordinates
        guard let windowFrame = window?.frame else { return }
        let screenRect = CGRect(
            x: windowFrame.origin.x + currentRect.origin.x,
            y: windowFrame.origin.y + currentRect.origin.y,
            width: currentRect.width,
            height: currentRect.height
        )

        let selectorWindowID = CGWindowID(window?.windowNumber ?? 0)

        DispatchQueue.main.async { [onSelection] in
            onSelection(screenRect, selectorWindowID)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            cancelSelection()
        }
    }

    override var acceptsFirstResponder: Bool { true }

    private func cancelSelection() {
        window?.close()

        DispatchQueue.main.async { [onCancel] in
            onCancel()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Semi-transparent overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        guard currentRect.width > 0 && currentRect.height > 0 else { return }

        // Clear the selected region (show actual screen content underneath)
        NSColor.clear.setFill()
        currentRect.fill(using: .copy)

        // Draw selection border
        let borderPath = NSBezierPath(rect: currentRect)
        NSColor.systemBlue.setStroke()
        borderPath.lineWidth = 2
        borderPath.stroke()

        // Draw dashed inner border
        let dashPath = NSBezierPath(rect: currentRect.insetBy(dx: 1, dy: 1))
        NSColor.white.setStroke()
        dashPath.lineWidth = 1
        dashPath.setLineDash([4, 4], count: 2, phase: 0)
        dashPath.stroke()

        // Draw dimension label
        let sizeText = "\(Int(currentRect.width)) × \(Int(currentRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .backgroundColor: NSColor.black.withAlphaComponent(0.6)
        ]
        let textSize = sizeText.size(withAttributes: attrs)
        let textOrigin = NSPoint(
            x: currentRect.midX - textSize.width / 2,
            y: currentRect.maxY + 4
        )
        sizeText.draw(at: textOrigin, withAttributes: attrs)
    }
}
