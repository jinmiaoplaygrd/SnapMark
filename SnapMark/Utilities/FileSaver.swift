import Cocoa
import UniformTypeIdentifiers

/// Saves an NSImage as PNG to disk.
struct FileSaver {
    static func save(image: NSImage, to url: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("⚠️ Failed to convert image to PNG")
            return
        }

        do {
            try pngData.write(to: url)
            print("✅ Saved to \(url.path)")
        } catch {
            print("⚠️ Failed to save: \(error)")
        }
    }
}
