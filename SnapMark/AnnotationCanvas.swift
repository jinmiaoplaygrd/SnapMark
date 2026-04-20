import Cocoa

/// The canvas view where annotations are drawn on top of the captured image.
class AnnotationCanvasView: NSView, NSTextViewDelegate {
    private let image: NSImage
    private var annotations: [Annotation] = []
    private var currentAnnotation: Annotation?
    private var dragStart: CGPoint?

    var currentTool: AnnotationTool = .rectangle
    var currentColor: NSColor = .systemRed
    var currentLineWidth: CGFloat = 3
    var currentFontSize: CGFloat = 16

    // For text input
    private var pendingTextPosition: CGPoint?
    private var textEditorScrollView: NSScrollView?
    private var textView: NSTextView?
    private var pendingTextColor: NSColor?
    private var pendingTextFontSize: CGFloat?
    private var pendingTextBoxWidth: CGFloat?

    private let textEditorMinWidth: CGFloat = 180
    private let textEditorMaxWidth: CGFloat = 320
    private let textEditorMinHeight: CGFloat = 36
    private let textEditorPadding = NSSize(width: 8, height: 6)

    init(frame: NSRect, image: NSImage) {
        self.image = image
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override var isFlipped: Bool { true }

    private var sourcePixelSize: NSSize {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return NSSize(width: cgImage.width, height: cgImage.height)
        }

        if let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first {
            return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }

        return bounds.size
    }

    // MARK: - Undo

    func undo() {
        if currentAnnotation != nil {
            currentAnnotation = nil
            dragStart = nil
            needsDisplay = true
            return
        }

        if textEditorScrollView != nil {
            discardPendingText()
            return
        }

        guard !annotations.isEmpty else { return }
        annotations.removeLast()
        needsDisplay = true
    }

    func removeLastAnnotation() {
        undo()
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if let editorFrame = textEditorScrollView?.frame, !editorFrame.contains(point) {
            commitPendingText(removeIfEmpty: true)
        }

        if currentTool == .text {
            showTextInput(at: point)
            return
        }

        dragStart = point

        switch currentTool {
        case .rectangle:
            currentAnnotation = .rectangle(RectangleAnnotation(
                rect: CGRect(origin: point, size: .zero),
                color: currentColor,
                lineWidth: currentLineWidth
            ))
        case .arrow:
            currentAnnotation = .arrow(ArrowAnnotation(
                start: point,
                end: point,
                color: currentColor,
                lineWidth: currentLineWidth
            ))
        case .pen:
            currentAnnotation = .pen(PenAnnotation(
                points: [point],
                color: currentColor,
                lineWidth: currentLineWidth
            ))
        case .text:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let start = dragStart else { return }

        switch currentTool {
        case .rectangle:
            let rect = rectFromPoints(start, point)
            currentAnnotation = .rectangle(RectangleAnnotation(
                rect: rect,
                color: currentColor,
                lineWidth: currentLineWidth
            ))
        case .arrow:
            currentAnnotation = .arrow(ArrowAnnotation(
                start: start,
                end: point,
                color: currentColor,
                lineWidth: currentLineWidth
            ))
        case .pen:
            if case .pen(var pen) = currentAnnotation {
                pen.points.append(point)
                currentAnnotation = .pen(pen)
            }
        case .text:
            break
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let annotation = currentAnnotation {
            annotations.append(annotation)
            currentAnnotation = nil
            dragStart = nil
            needsDisplay = true
        }
    }

    // MARK: - Text Input

    private func showTextInput(at point: CGPoint) {
        commitPendingText(removeIfEmpty: true)

        let availableWidth = max(1, bounds.width - point.x - 16)
        let editorWidth = min(textEditorMaxWidth, max(textEditorMinWidth, availableWidth))
        let editorFrame = NSRect(x: point.x, y: point.y, width: editorWidth, height: textEditorMinHeight)

        let scrollView = NSScrollView(frame: editorFrame)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .lineBorder
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.45).cgColor
        scrollView.layer?.borderWidth = 1

        let textContainer = NSTextContainer(size: NSSize(width: editorWidth, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineBreakMode = .byWordWrapping

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let editor = NSTextView(frame: scrollView.bounds, textContainer: textContainer)
        editor.minSize = NSSize(width: editorWidth, height: textEditorMinHeight)
        editor.maxSize = NSSize(width: editorWidth, height: .greatestFiniteMagnitude)
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.drawsBackground = false
        editor.font = NSFont.systemFont(ofSize: currentFontSize, weight: .semibold)
        editor.textColor = currentColor
        editor.insertionPointColor = currentColor
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.delegate = self
        editor.textContainerInset = textEditorPadding
        editor.string = ""

        if let textContainer = editor.textContainer {
            textContainer.containerSize = NSSize(width: editorWidth, height: .greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
            textContainer.lineBreakMode = .byWordWrapping
        }

        scrollView.documentView = editor

        addSubview(scrollView)
        window?.makeFirstResponder(editor)

        pendingTextPosition = point
        textEditorScrollView = scrollView
        textView = editor
        pendingTextColor = currentColor
        pendingTextFontSize = currentFontSize
        pendingTextBoxWidth = editorWidth - (textEditorPadding.width * 2)

        updateTextEditorLayout()   
    }

    func textDidChange(_ notification: Notification) {
        updateTextEditorLayout()
    }

    private func commitPendingText(removeIfEmpty: Bool) {
        guard let scrollView = textEditorScrollView, let editor = textView else { return }

        let text = editor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, let pos = pendingTextPosition {
            annotations.append(.text(TextAnnotation(
                text: text,
                position: pos,
                color: pendingTextColor ?? currentColor,
                fontSize: pendingTextFontSize ?? currentFontSize,
                boxWidth: pendingTextBoxWidth ?? max(120, scrollView.frame.width - textEditorPadding.width * 2)
            )))
            needsDisplay = true
        }

        if removeIfEmpty || !text.isEmpty {
            scrollView.removeFromSuperview()
            textEditorScrollView = nil
            textView = nil
            pendingTextPosition = nil
            pendingTextColor = nil
            pendingTextFontSize = nil
            pendingTextBoxWidth = nil
        }
    }

    private func discardPendingText() {
        guard let scrollView = textEditorScrollView else { return }

        scrollView.removeFromSuperview()
        textEditorScrollView = nil
        textView = nil
        pendingTextPosition = nil
        pendingTextColor = nil
        pendingTextFontSize = nil
        pendingTextBoxWidth = nil
        needsDisplay = true
    }

    func textDidEndEditing(_ notification: Notification) {
        commitPendingText(removeIfEmpty: true)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            commitPendingText(removeIfEmpty: true)
            return
        }

        super.keyDown(with: event)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw the captured image
        image.draw(in: bounds)

        // Draw committed annotations
        for annotation in annotations {
            drawAnnotation(annotation)
        }

        // Draw in-progress annotation
        if let current = currentAnnotation {
            drawAnnotation(current)
        }
    }

    private func drawAnnotation(_ annotation: Annotation) {
        switch annotation {
        case .rectangle(let rect):
            drawRectangleAnnotation(rect)
        case .arrow(let arrow):
            drawArrowAnnotation(arrow)
        case .text(let text):
            drawTextAnnotation(text)
        case .pen(let pen):
            drawPenAnnotation(pen)
        }
    }

    private func drawRectangleAnnotation(_ ann: RectangleAnnotation) {
        let path = NSBezierPath(rect: ann.rect)
        ann.color.setStroke()
        path.lineWidth = ann.lineWidth
        path.stroke()
    }

    private func drawArrowAnnotation(_ ann: ArrowAnnotation) {
        let path = NSBezierPath()
        path.move(to: ann.start)
        path.line(to: ann.end)
        ann.color.setStroke()
        path.lineWidth = ann.lineWidth
        path.stroke()

        // Arrowhead
        drawArrowhead(from: ann.start, to: ann.end, color: ann.color, lineWidth: ann.lineWidth)
    }

    private func drawArrowhead(from start: CGPoint, to end: CGPoint, color: NSColor, lineWidth: CGFloat) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return }

        let unitDx = dx / length
        let unitDy = dy / length

        let arrowLength: CGFloat = max(12, lineWidth * 4)
        let arrowWidth: CGFloat = max(6, lineWidth * 2)

        let p1 = CGPoint(
            x: end.x - arrowLength * unitDx + arrowWidth * unitDy,
            y: end.y - arrowLength * unitDy - arrowWidth * unitDx
        )
        let p2 = CGPoint(
            x: end.x - arrowLength * unitDx - arrowWidth * unitDy,
            y: end.y - arrowLength * unitDy + arrowWidth * unitDx
        )

        let path = NSBezierPath()
        path.move(to: end)
        path.line(to: p1)
        path.line(to: p2)
        path.close()
        color.setFill()
        path.fill()
    }

    private func drawTextAnnotation(_ ann: TextAnnotation) {
        let attributedText = makeAttributedText(for: ann)
        let textRect = rectForTextAnnotation(ann, attributedText: attributedText)
        let bgRect = NSRect(
            x: textRect.minX - 4,
            y: textRect.minY - 3,
            width: textRect.width + 8,
            height: textRect.height + 6
        )
        NSColor.white.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: 3, yRadius: 3).fill()

        attributedText.draw(in: textRect)
    }

    private func drawPenAnnotation(_ ann: PenAnnotation) {
        guard ann.points.count > 1 else { return }
        let path = NSBezierPath()
        path.move(to: ann.points[0])
        for point in ann.points.dropFirst() {
            path.line(to: point)
        }
        ann.color.setStroke()
        path.lineWidth = ann.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    // MARK: - Render Final Image

    func renderFinalImage() -> NSImage? {
        commitPendingText(removeIfEmpty: true)

        let pixelSize = sourcePixelSize
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        rep.size = image.size
        cacheDisplay(in: bounds, to: rep)

        let finalImage = NSImage(size: image.size)
        finalImage.addRepresentation(rep)
        return finalImage
    }

    // MARK: - Helpers

    private func updateTextEditorLayout() {
        guard let scrollView = textEditorScrollView, let editor = textView, let layoutManager = editor.layoutManager else {
            return
        }

        layoutManager.ensureLayout(for: editor.textContainer!)
        let usedRect = layoutManager.usedRect(for: editor.textContainer!)
        let contentHeight = max(textEditorMinHeight, ceil(usedRect.height + (textEditorPadding.height * 2)))
        let remainingHeight = max(textEditorMinHeight, bounds.height - scrollView.frame.minY - 12)
        let height = min(remainingHeight, contentHeight)

        scrollView.frame.size.height = height
        editor.frame = NSRect(origin: .zero, size: NSSize(width: scrollView.frame.width, height: height))
    }

    private func makeAttributedText(for annotation: TextAnnotation) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        return NSAttributedString(string: annotation.text, attributes: [
            .foregroundColor: annotation.color,
            .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
            .paragraphStyle: paragraph,
        ])
    }

    private func rectForTextAnnotation(_ annotation: TextAnnotation, attributedText: NSAttributedString) -> NSRect {
        let constrainedSize = NSSize(width: annotation.boxWidth, height: .greatestFiniteMagnitude)
        let measured = attributedText.boundingRect(with: constrainedSize, options: [.usesLineFragmentOrigin, .usesFontLeading])
        return NSRect(
            x: annotation.position.x,
            y: annotation.position.y,
            width: annotation.boxWidth,
            height: ceil(measured.height)
        )
    }

    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGRect {
        CGRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width: abs(p2.x - p1.x),
            height: abs(p2.y - p1.y)
        )
    }
}
