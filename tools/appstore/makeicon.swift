import AppKit

// Waymark app icon — a route that climbs from lower-left to upper-right with
// waypoint dots along it and a map pin at the destination. Full-bleed 1024.

func render(to url: URL, style: String) {
    let S: CGFloat = 1024
    let img = NSImage(size: NSSize(width: S, height: S))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setAllowsAntialiasing(true)

    // ---- background ----
    let colors: [CGColor]
    let pinFill: NSColor
    switch style {
    case "dark":
        colors = [NSColor(srgbRed: 0.13, green: 0.17, blue: 0.30, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.05, green: 0.07, blue: 0.14, alpha: 1).cgColor]
        pinFill = NSColor(srgbRed: 0.13, green: 0.17, blue: 0.30, alpha: 1)
    case "tinted":
        colors = [NSColor.black.cgColor, NSColor.black.cgColor]
        pinFill = NSColor.black
    default:
        colors = [NSColor(srgbRed: 0.21, green: 0.44, blue: 0.93, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.08, green: 0.20, blue: 0.58, alpha: 1).cgColor]
        pinFill = NSColor(srgbRed: 0.09, green: 0.22, blue: 0.60, alpha: 1)
    }
    let space = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

    let white = NSColor.white.cgColor

    // ---- the route: a dashed climbing path ----
    let origin = CGPoint(x: 265, y: 285)
    let route = CGMutablePath()
    route.move(to: origin)
    route.addCurve(to: CGPoint(x: 545, y: 470),
                   control1: CGPoint(x: 455, y: 285),
                   control2: CGPoint(x: 400, y: 470))

    ctx.saveGState()
    ctx.setStrokeColor(white)
    ctx.setLineWidth(64)
    ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [2, 150])   // round dots
    ctx.addPath(route)
    if style != "tinted" {
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30,
                      color: NSColor(white: 0, alpha: 0.22).cgColor)
    }
    ctx.strokePath()
    ctx.restoreGState()

    // ---- origin dot ----
    ctx.saveGState()
    if style != "tinted" {
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24,
                      color: NSColor(white: 0, alpha: 0.22).cgColor)
    }
    ctx.setFillColor(white)
    let s: CGFloat = 52
    ctx.fillEllipse(in: CGRect(x: origin.x - s, y: origin.y - s, width: s * 2, height: s * 2))
    ctx.restoreGState()

    // ---- destination pin (circle head + triangle point, unioned by overfill) ----
    let cx: CGFloat = 620
    let r: CGFloat = 140
    let cy: CGFloat = 660          // head centre
    let tip = CGPoint(x: cx, y: cy - r - 140)

    ctx.saveGState()
    if style != "tinted" {
        ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 46,
                      color: NSColor(white: 0, alpha: 0.32).cgColor)
    }
    ctx.setFillColor(white)
    let tri = CGMutablePath()
    tri.move(to: tip)
    tri.addLine(to: CGPoint(x: cx - r * 0.92, y: cy - r * 0.30))
    tri.addLine(to: CGPoint(x: cx + r * 0.92, y: cy - r * 0.30))
    tri.closeSubpath()
    ctx.addPath(tri)
    ctx.fillPath()
    ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    ctx.restoreGState()

    // pin hole
    ctx.setFillColor(pinFill.cgColor)
    let holeR: CGFloat = 58
    ctx.fillEllipse(in: CGRect(x: cx - holeR, y: cy - holeR, width: holeR * 2, height: holeR * 2))

    img.unlockFocus()

    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("encode failed")
    }
    try! png.write(to: url)
    print("wrote \(url.lastPathComponent)")
}

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
render(to: dir.appendingPathComponent("AppIcon-1024.png"), style: "light")
render(to: dir.appendingPathComponent("AppIcon-1024-dark.png"), style: "dark")
render(to: dir.appendingPathComponent("AppIcon-1024-tinted.png"), style: "tinted")
