import Cocoa

/// Copies an NSImage to the system clipboard.
struct ClipboardManager {
    static func copy(image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let item = NSPasteboardItem()
            item.setData(pngData, forType: .png)
            item.setData(tiffData, forType: .tiff)
            pasteboard.writeObjects([item])
            return
        }

        pasteboard.writeObjects([image])
    }
}
