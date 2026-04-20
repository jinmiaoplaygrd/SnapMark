import Cocoa

/// The toolbar shown above the annotation canvas with tool, color, and size controls.
class AnnotationToolbarView: NSView {
    private enum OverflowItemKind {
        case tool(AnnotationTool)
        case color(NSColor, String)
        case lineWidth(CGFloat, String)
        case action(Selector)
    }

    private struct OverflowDescriptor {
        let title: String
        let imageName: String?
        let kind: OverflowItemKind
    }

    private enum ToolbarEntryKind {
        case control(OverflowDescriptor)
        case separator
    }

    private struct ToolbarEntry {
        let view: NSView
        let width: CGFloat
        let kind: ToolbarEntryKind
    }

    private weak var canvasView: AnnotationCanvasView?

    private var toolButtons: [AnnotationTool: NSButton] = [:]
    private var colorButtons: [(color: NSColor, name: String, button: NSButton)] = []
    private var widthButtons: [(width: CGFloat, title: String, button: NSButton)] = []
    private var selectedTool: AnnotationTool = .rectangle
    private var toolbarEntries: [ToolbarEntry] = []
    private var hiddenOverflowItems: [OverflowDescriptor] = []
    private let overflowButton = NSButton(frame: .zero)

    init(frame: NSRect, canvasView: AnnotationCanvasView) {
        self.canvasView = canvasView
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var isFlipped: Bool { false }

    override func layout() {
        super.layout()
        layoutToolbarEntries()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        setupOverflowButton()

        var entries: [ToolbarEntry] = []

        for tool in AnnotationTool.allCases {
            let button = NSButton(frame: .zero)
            button.bezelStyle = .toolbar
            button.image = NSImage(systemSymbolName: tool.iconName, accessibilityDescription: tool.rawValue)
            button.imagePosition = .imageOnly
            button.toolTip = tool.rawValue
            button.target = self
            button.action = #selector(toolSelected(_:))
            button.tag = AnnotationTool.allCases.firstIndex(of: tool)!
            addSubview(button)
            toolButtons[tool] = button

            entries.append(ToolbarEntry(
                view: button,
                width: 34,
                kind: .control(OverflowDescriptor(title: tool.rawValue, imageName: tool.iconName, kind: .tool(tool)))
            ))
        }

        entries.append(ToolbarEntry(view: makeSeparatorView(), width: 1, kind: .separator))

        let colors: [(NSColor, String)] = [
            (.systemRed, "Red"),
            (.systemBlue, "Blue"),
            (.systemGreen, "Green"),
            (.systemYellow, "Yellow"),
            (.systemOrange, "Orange"),
            (.black, "Black"),
            (.white, "White")
        ]
        for (index, colorEntry) in colors.enumerated() {
            let button = NSButton(frame: .zero)
            button.bezelStyle = .toolbar
            button.wantsLayer = true
            button.layer?.backgroundColor = colorEntry.0.cgColor
            button.layer?.cornerRadius = 12
            button.layer?.borderWidth = 2
            button.layer?.borderColor = NSColor.separatorColor.cgColor
            button.title = ""
            button.toolTip = colorEntry.1
            button.target = self
            button.action = #selector(colorSelected(_:))
            button.tag = index
            addSubview(button)
            colorButtons.append((color: colorEntry.0, name: colorEntry.1, button: button))

            entries.append(ToolbarEntry(
                view: button,
                width: 24,
                kind: .control(OverflowDescriptor(title: colorEntry.1, imageName: nil, kind: .color(colorEntry.0, colorEntry.1)))
            ))
        }

        entries.append(ToolbarEntry(view: makeSeparatorView(), width: 1, kind: .separator))

        let lineWidths: [(CGFloat, String)] = [(2, "Thin"), (3, "Med"), (6, "Thick")]
        for (width, title) in lineWidths {
            let button = makeWidthButton(label: title, width: width)
            addSubview(button)
            widthButtons.append((width: width, title: title, button: button))

            entries.append(ToolbarEntry(
                view: button,
                width: title == "Thick" ? 54 : 44,
                kind: .control(OverflowDescriptor(title: title, imageName: nil, kind: .lineWidth(width, title)))
            ))
        }

        entries.append(ToolbarEntry(view: makeSeparatorView(), width: 1, kind: .separator))

        let actionButtons: [(String, String, Selector)] = [
            ("doc.on.clipboard", "Copy to Clipboard", #selector(copyAction)),
            ("square.and.arrow.down", "Save to File", #selector(saveAction)),
            ("arrow.uturn.backward", "Undo", #selector(undoAction)),
            ("trash", "Remove Last", #selector(deleteAction))
        ]
        for (symbol, title, selector) in actionButtons {
            let button = NSButton(frame: .zero)
            button.bezelStyle = .toolbar
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            button.imagePosition = .imageOnly
            button.toolTip = title
            button.target = self
            button.action = selector
            addSubview(button)

            entries.append(ToolbarEntry(
                view: button,
                width: 34,
                kind: .control(OverflowDescriptor(title: title, imageName: symbol, kind: .action(selector)))
            ))
        }

        toolbarEntries = entries
        updateToolSelection()
        updateColorSelection()
        updateWidthSelection()
    }

    private func setupOverflowButton() {
        overflowButton.bezelStyle = .toolbar
        overflowButton.title = "..."
        overflowButton.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        overflowButton.target = self
        overflowButton.action = #selector(showOverflowMenu(_:))
        overflowButton.toolTip = "More"
        overflowButton.isHidden = true
        addSubview(overflowButton)
    }

    private func layoutToolbarEntries() {
        let buttonY: CGFloat = 8
        let colorButtonY: CGFloat = 12
        let widthButtonY: CGFloat = 10
        let separatorY: CGFloat = 6
        let separatorHeight: CGFloat = 38
        let sidePadding = ToolbarOverflowRules.sidePadding
        let overflowWidth = ToolbarOverflowRules.overflowWidth
        let visibleCount = ToolbarOverflowRules.visibleEntryCount(
            entries: toolbarEntries.map {
                ToolbarOverflowRules.Entry(
                    width: $0.width,
                    kind: overflowRuleKind(for: $0.kind)
                )
            },
            availableWidth: bounds.width
        )

        let visibleEntries = Array(toolbarEntries.prefix(visibleCount))
        hiddenOverflowItems = toolbarEntries.suffix(toolbarEntries.count - visibleCount).compactMap {
            guard case .control(let descriptor) = $0.kind else { return nil }
            return descriptor
        }

        var xOffset = sidePadding
        for (index, entry) in visibleEntries.enumerated() {
            entry.view.isHidden = false

            switch entry.kind {
            case .separator:
                entry.view.frame = NSRect(x: xOffset, y: separatorY, width: 1, height: separatorHeight)
            case .control:
                let frame: NSRect
                if colorButtons.contains(where: { $0.button === entry.view }) {
                    frame = NSRect(x: xOffset, y: colorButtonY, width: entry.width, height: 24)
                } else if widthButtons.contains(where: { $0.button === entry.view }) {
                    frame = NSRect(x: xOffset, y: widthButtonY, width: entry.width, height: 28)
                } else {
                    frame = NSRect(x: xOffset, y: buttonY, width: entry.width, height: 34)
                }
                entry.view.frame = frame
            }

            xOffset += entry.width
            if index < visibleEntries.count - 1 {
                xOffset += ToolbarOverflowRules.spacing(after: overflowRuleKind(for: entry.kind))
            }
        }

        for entry in toolbarEntries.suffix(toolbarEntries.count - visibleCount) {
            entry.view.isHidden = true
        }

        overflowButton.isHidden = hiddenOverflowItems.isEmpty
        if !hiddenOverflowItems.isEmpty {
            overflowButton.frame = NSRect(x: bounds.width - sidePadding - overflowWidth, y: buttonY, width: overflowWidth, height: 34)
        }
    }

    // MARK: - Actions

    @objc private func toolSelected(_ sender: NSButton) {
        let tools = AnnotationTool.allCases
        selectedTool = tools[sender.tag]
        canvasView?.currentTool = selectedTool
        updateToolSelection()
    }

    @objc private func colorSelected(_ sender: NSButton) {
        let selected = colorButtons[sender.tag]
        canvasView?.currentColor = selected.color
        updateColorSelection()
    }

    @objc private func copyAction() {
        guard let image = canvasView?.renderFinalImage() else { return }
        ClipboardManager.copy(image: image)
    }

    @objc private func saveAction() {
        NSApp.sendAction(#selector(AnnotationEditorViewController.performSave), to: nil, from: self)
    }

    @objc private func undoAction() {
        canvasView?.undo()
    }

    @objc private func deleteAction() {
        canvasView?.removeLastAnnotation()
    }

    @objc private func widthSelected(_ sender: NSButton) {
        let width = CGFloat(sender.tag) / 10.0
        canvasView?.currentLineWidth = width
        updateWidthSelection()
    }

    @objc private func showOverflowMenu(_ sender: NSButton) {
        guard !hiddenOverflowItems.isEmpty else { return }

        let menu = NSMenu()
        for descriptor in hiddenOverflowItems {
            let item = NSMenuItem(title: descriptor.title, action: #selector(handleOverflowMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = descriptor
            if let imageName = descriptor.imageName {
                item.image = NSImage(systemSymbolName: imageName, accessibilityDescription: descriptor.title)
            }
            configureOverflowState(for: item, descriptor: descriptor)
            menu.addItem(item)
        }

        let menuOrigin = NSPoint(x: sender.frame.minX, y: sender.frame.minY - 4)
        menu.popUp(positioning: nil, at: menuOrigin, in: self)
    }

    @objc private func handleOverflowMenuAction(_ sender: NSMenuItem) {
        guard let descriptor = sender.representedObject as? OverflowDescriptor else { return }

        switch descriptor.kind {
        case .tool(let tool):
            selectedTool = tool
            canvasView?.currentTool = tool
            updateToolSelection()
        case .color(let color, _):
            canvasView?.currentColor = color
            updateColorSelection()
        case .lineWidth(let width, _):
            canvasView?.currentLineWidth = width
            updateWidthSelection()
        case .action(let selector):
            _ = tryToPerform(selector, with: self)
        }
    }

    private func configureOverflowState(for item: NSMenuItem, descriptor: OverflowDescriptor) {
        switch descriptor.kind {
        case .tool(let tool):
            item.state = tool == selectedTool ? .on : .off
        case .color(let color, _):
            item.state = colorsEqual(canvasView?.currentColor, color) ? .on : .off
        case .lineWidth(let width, _):
            item.state = canvasView?.currentLineWidth == width ? .on : .off
        case .action:
            item.state = .off
        }
    }

    private func updateToolSelection() {
        for (tool, button) in toolButtons {
            button.state = tool == selectedTool ? .on : .off
        }
    }

    private func updateColorSelection() {
        for entry in colorButtons {
            let isSelected = colorsEqual(canvasView?.currentColor, entry.color)
            entry.button.layer?.borderColor = isSelected ? NSColor.controlAccentColor.cgColor : NSColor.separatorColor.cgColor
            entry.button.layer?.borderWidth = isSelected ? 3 : 2
        }
    }

    private func updateWidthSelection() {
        for entry in widthButtons {
            entry.button.state = canvasView?.currentLineWidth == entry.width ? .on : .off
        }
    }

    // MARK: - Helpers

    private func makeSeparatorView() -> NSView {
        let separator = NSView(frame: .zero)
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(separator)
        return separator
    }

    private func makeWidthButton(label: String, width: CGFloat) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .toolbar
        button.title = label
        button.font = NSFont.systemFont(ofSize: 11)
        button.target = self
        button.action = #selector(widthSelected(_:))
        button.tag = Int(width * 10)
        return button
    }

    private func colorsEqual(_ lhs: NSColor?, _ rhs: NSColor) -> Bool {
        guard let lhsColor = lhs?.usingColorSpace(.deviceRGB),
              let rhsColor = rhs.usingColorSpace(.deviceRGB) else {
            return false
        }

        return lhsColor == rhsColor
    }

    private func overflowRuleKind(for kind: ToolbarEntryKind) -> ToolbarOverflowRules.EntryKind {
        switch kind {
        case .control:
            return .control
        case .separator:
            return .separator
        }
    }
}

// Extension for responder chain save
extension AnnotationEditorViewController {
    @objc func performSave() {
        // Forward to the save logic
        guard let image = (view.subviews.compactMap { $0 as? AnnotationCanvasView }.first)?.renderFinalImage() else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd_HHmmss"
        panel.nameFieldStringValue = "SnapMark_\(fmt.string(from: Date())).png"

        panel.beginSheetModal(for: view.window!) { response in
            if response == .OK, let url = panel.url {
                FileSaver.save(image: image, to: url)
            }
        }
    }
}
