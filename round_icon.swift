import Cocoa
import CoreGraphics

let inputPath = "/Users/charlie/.gemini/antigravity-ide/brain/808203c7-af04-48da-b6ed-184f81853bbf/oathkeeper_logo_1781124723442.png"
let outputPath = "/Users/charlie/oathkeeper/rounded_logo.png"

guard let image = NSImage(contentsOfFile: inputPath) else {
    print("Could not load image at \(inputPath)")
    exit(1)
}

let size = image.size
let rect = NSRect(origin: .zero, size: size)

let newImage = NSImage(size: size)
newImage.lockFocus()

// macOS standard app icon corner radius is roughly 22.5% of the dimension
let radius = size.width * 0.225
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
path.addClip()

image.draw(in: rect)

newImage.unlockFocus()

guard let tiffData = newImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to generate PNG data")
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Successfully wrote rounded icon to \(outputPath)")
} catch {
    print("Error writing file: \(error)")
    exit(1)
}
