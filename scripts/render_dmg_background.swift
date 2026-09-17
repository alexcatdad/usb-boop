import AppKit

// Finder's icon-view canvas is 640 × 420 points. Render at 2× for Retina.
guard CommandLine.arguments.count == 2,
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1280,
                                    pixelsHigh: 840, bitsPerSample: 8,
                                    samplesPerPixel: 4, hasAlpha: true,
                                    isPlanar: false, colorSpaceName: .deviceRGB,
                                    bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("usage: swift scripts/render_dmg_background.swift <output.png>")
}
NSGraphicsContext.saveGraphicsState()
bitmap.size = NSSize(width: 640, height: 420)
NSGraphicsContext.current = context
context.cgContext.scaleBy(x: 2, y: 2)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}
let ink = color(25, 48, 58)
let teal = color(34, 125, 121)
color(239, 248, 245).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 640, height: 420)).fill()

func centered(_ text: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight,
              color: NSColor, rounded: Bool = false) {
    var font = NSFont.systemFont(ofSize: size, weight: weight)
    if rounded, let descriptor = font.fontDescriptor.withDesign(.rounded),
       let roundedFont = NSFont(descriptor: descriptor, size: size) {
        font = roundedFont
    }
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    (text as NSString).draw(in: NSRect(x: 30, y: y, width: 580, height: size * 1.5),
                           withAttributes: [.font: font, .foregroundColor: color,
                                            .paragraphStyle: style])
}
centered("Install usb-boop", y: 328, size: 32, weight: .bold, color: ink, rounded: true)
centered("A little boop for your Mac.", y: 298, size: 17, weight: .regular, color: teal)

// Quiet colour behind the two real Finder icons, not fake buttons.
color(255, 231, 195).setFill()
NSBezierPath(ovalIn: NSRect(x: 97, y: 147, width: 146, height: 146)).fill()
color(212, 235, 229).setFill()
NSBezierPath(ovalIn: NSRect(x: 397, y: 147, width: 146, height: 146)).fill()

// A gently curled cable points toward Applications.
teal.setStroke()
let cable = NSBezierPath()
cable.lineWidth = 3
cable.lineCapStyle = .round
cable.lineJoinStyle = .round
cable.move(to: NSPoint(x: 279, y: 219))
cable.curve(to: NSPoint(x: 361, y: 219), controlPoint1: NSPoint(x: 300, y: 243),
            controlPoint2: NSPoint(x: 337, y: 195))
cable.move(to: NSPoint(x: 350, y: 210))
cable.line(to: NSPoint(x: 361, y: 219))
cable.line(to: NSPoint(x: 351, y: 229))
cable.stroke()

centered("Drag usb-boop into Applications.", y: 60, size: 17, weight: .semibold, color: ink)
centered("Then open it from Applications.", y: 34, size: 13, weight: .regular, color: teal)
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode background")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
