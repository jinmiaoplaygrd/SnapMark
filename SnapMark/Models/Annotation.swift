import Foundation
import Cocoa

/// The type of annotation tool currently selected.
enum AnnotationTool: String, CaseIterable, Identifiable {
    case rectangle = "Rectangle"
    case arrow = "Arrow"
    case text = "Text"
    case pen = "Pen"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .rectangle: return "rectangle"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .pen: return "pencil.tip"
        }
    }
}

/// A single annotation drawn on the image.
enum Annotation {
    case rectangle(RectangleAnnotation)
    case arrow(ArrowAnnotation)
    case text(TextAnnotation)
    case pen(PenAnnotation)
}

struct RectangleAnnotation {
    var rect: CGRect
    var color: NSColor
    var lineWidth: CGFloat
}

struct ArrowAnnotation {
    var start: CGPoint
    var end: CGPoint
    var color: NSColor
    var lineWidth: CGFloat
}

struct TextAnnotation {
    var text: String
    var position: CGPoint
    var color: NSColor
    var fontSize: CGFloat
    var boxWidth: CGFloat
}

struct PenAnnotation {
    var points: [CGPoint]
    var color: NSColor
    var lineWidth: CGFloat
}
