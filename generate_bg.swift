import Cocoa

let width: CGFloat = 1600
let height: CGFloat = 800
let rect = CGRect(x: 0, y: 0, width: width, height: height)

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue
guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) else {
    fatalError("Failed to create context")
}

// 1. Fill base dark color
context.setFillColor(NSColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0).cgColor)
context.fill(rect)

// 2. Draw mesh gradient orbs for a premium Apple-like abstract dark background
func drawOrb(center: CGPoint, radius: CGFloat, color: NSColor) {
    let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
    let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
    context.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

// Organic dark mode auroras
drawOrb(center: CGPoint(x: 200, y: 700), radius: 900, color: NSColor(red: 0.2, green: 0.15, blue: 0.4, alpha: 0.4))
drawOrb(center: CGPoint(x: 1400, y: 900), radius: 1000, color: NSColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 0.3))
drawOrb(center: CGPoint(x: 800, y: 500), radius: 800, color: NSColor(red: 0.1, green: 0.4, blue: 0.5, alpha: 0.2))

// Add extra background nebulas for a richer natural feel
drawOrb(center: CGPoint(x: 500, y: 150), radius: 600, color: NSColor(red: 0.25, green: 0.1, blue: 0.35, alpha: 0.25))
drawOrb(center: CGPoint(x: 1100, y: 650), radius: 700, color: NSColor(red: 0.05, green: 0.25, blue: 0.55, alpha: 0.2))
drawOrb(center: CGPoint(x: 800, y: 200), radius: 500, color: NSColor(red: 0.15, green: 0.3, blue: 0.4, alpha: 0.15))

// 3. Draw identical, pure white glows exactly behind the text for AAA contrast
func drawTextGlow(baseCenter: CGPoint) {
    context.saveGState()
    context.translateBy(x: baseCenter.x, y: baseCenter.y)
    
    context.saveGState()
    context.scaleBy(x: 1.0, y: 0.35) // Squash to a clean ellipse
    
    // Create a gradient that is pure solid white in the center for AAA contrast,
    // and only fades out near the edges.
    let colors = [
        NSColor(white: 1.0, alpha: 1.0).cgColor,
        NSColor(white: 1.0, alpha: 1.0).cgColor,
        NSColor(white: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    
    let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.6, 1.0])!
    context.drawRadialGradient(grad, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 210, options: [])
    
    context.restoreGState()
    context.restoreGState()
}

drawTextGlow(baseCenter: CGPoint(x: 400, y: 250))
drawTextGlow(baseCenter: CGPoint(x: 1200, y: 250))

// 4. Draw unique, professional arrow
let arrowY: CGFloat = 420 
let startX: CGFloat = 560
let endX: CGFloat = 1040

// Draw glowing dashed trajectory
context.saveGState()
let dashPattern: [CGFloat] = [12, 12]
context.setLineDash(phase: 0, lengths: dashPattern)
context.setStrokeColor(NSColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.5).cgColor)
context.setLineWidth(4)
context.setLineCap(.round)
context.move(to: CGPoint(x: startX, y: arrowY))
context.addLine(to: CGPoint(x: endX - 45, y: arrowY))
context.strokePath()
context.restoreGState()

// Draw double-chevron arrow head with a glowing shadow
context.setStrokeColor(NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0).cgColor)
context.setLineWidth(5)
context.setLineCap(.round)
context.setLineJoin(.round)
context.setShadow(offset: CGSize(width: 0, height: 0), blur: 12, color: NSColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.8).cgColor)

// First chevron
context.move(to: CGPoint(x: endX - 50, y: arrowY - 22))
context.addLine(to: CGPoint(x: endX - 25, y: arrowY))
context.addLine(to: CGPoint(x: endX - 50, y: arrowY + 22))
context.strokePath()

// Second chevron
context.move(to: CGPoint(x: endX - 25, y: arrowY - 22))
context.addLine(to: CGPoint(x: endX, y: arrowY))
context.addLine(to: CGPoint(x: endX - 25, y: arrowY + 22))
context.strokePath()

// Clear shadow
context.setShadow(offset: .zero, blur: 0, color: nil)

// (Removed "Drag to Install" text completely as requested)

// 5. Save image
guard let cgImage = context.makeImage() else {
    fatalError("Failed to create image")
}

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
    let url = URL(fileURLWithPath: "/Users/charlie/oathkeeper/dmg_background_custom_2x.png")
    try! pngData.write(to: url)
}
