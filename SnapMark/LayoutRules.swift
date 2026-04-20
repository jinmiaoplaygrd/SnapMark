import CoreGraphics

struct AnnotationEditorLayoutRules {
    static let toolbarHeight: CGFloat = 50
    static let minimumWindowSize = CGSize(width: 180, height: 120)

    static func contentSize(for imageSize: CGSize) -> CGSize {
        CGSize(
            width: max(1, ceil(imageSize.width)),
            height: max(1, ceil(imageSize.height)) + toolbarHeight
        )
    }

    static func canvasHeight(for imageSize: CGSize) -> CGFloat {
        max(1, ceil(imageSize.height))
    }
}

struct ToolbarOverflowRules {
    enum EntryKind {
        case control
        case separator
    }

    struct Entry {
        let width: CGFloat
        let kind: EntryKind
    }

    static let sidePadding: CGFloat = 10
    static let controlSpacing: CGFloat = 6
    static let separatorSpacing: CGFloat = 10
    static let overflowWidth: CGFloat = 34

    static func visibleEntryCount(entries: [Entry], availableWidth: CGFloat) -> Int {
        var visibleCount = entries.count
        while visibleCount > 0 {
            let needsOverflow = visibleCount < entries.count
            if requiredWidth(for: entries, visibleCount: visibleCount, includesOverflow: needsOverflow) <= availableWidth {
                break
            }
            visibleCount -= 1
        }

        while visibleCount > 0, entries[visibleCount - 1].kind == .separator {
            visibleCount -= 1
        }

        return visibleCount
    }

    private static func requiredWidth(for entries: [Entry], visibleCount: Int, includesOverflow: Bool) -> CGFloat {
        guard visibleCount > 0 else {
            return sidePadding * 2 + (includesOverflow ? overflowWidth : 0)
        }

        var width = sidePadding * 2
        for index in 0..<visibleCount {
            let entry = entries[index]
            width += entry.width
            if index < visibleCount - 1 {
                width += spacing(after: entry.kind)
            }
        }

        if includesOverflow {
            width += controlSpacing + overflowWidth
        }

        return width
    }

    static func spacing(after entry: EntryKind) -> CGFloat {
        switch entry {
        case .control:
            return controlSpacing
        case .separator:
            return separatorSpacing
        }
    }
}