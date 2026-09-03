import AppKit

// Compose a raw 1320x2868 simulator screenshot into an App Store marketing frame.

let W: CGFloat = 1320, H: CGFloat = 2868

struct Shot { let file: String; let headline: String; let out: String }

let args = CommandLine.arguments
let shotsDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let locale = args[3]

let sets: [String: [Shot]] = [
    "en": [
        Shot(file: "01-home.png",   headline: "Every place you drive through",       out: "en-1-home.png"),
        Shot(file: "02-active.png",  headline: "Know where you are, the moment you arrive", out: "en-2-active.png"),
        Shot(file: "03-summary.png", headline: "A timeline of everywhere you passed", out: "en-3-summary.png"),
    ],
    "tr": [
        Shot(file: "01-home.png",   headline: "Yolda geçtiğin her yer",              out: "tr-1-home.png"),
        Shot(file: "02-active.png",  headline: "Girdiğin anda nerede olduğunu öğren", out: "tr-2-active.png"),
        Shot(file: "03-summary.png", headline: "Geçtiğin her yerin zaman çizelgesi",  out: "tr-3-summary.png"),
    ],
]

func frame(_ shot: Shot) {
    let img = NSImage(size: NSSize(width: W, height: H))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    let space = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: space, colors: [
        NSColor(srgbRed: 0.20, green: 0.42, blue: 0.92, alpha: 1).cgColor,
        NSColor(srgbRed: 0.10, green: 0.24, blue: 0.62, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])

    // headline — top band, ~y 2868..2400 (bottom-left origin)
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineSpacing = 8
    let title = NSAttributedString(string: shot.headline, attributes: [
        .font: NSFont.systemFont(ofSize: 78, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
    ])
    let band = NSRect(x: 90, y: H - 470, width: W - 180, height: 380)
    title.draw(with: band, options: [.usesLineFragmentOrigin, .usesFontLeading])

    // screenshot — centred, below the band, may bleed slightly off the bottom
    guard let raw = NSImage(contentsOf: shotsDir.appendingPathComponent(shot.file)) else {
        fatalError("missing \(shot.file)")
    }
    let shotW: CGFloat = 1120
    let shotH = H * (shotW / W)
    let x = (W - shotW) / 2
    let y = H - 500 - shotH        // top edge sits 500pt down from the top

    let clip = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: shotW, height: shotH),
                            xRadius: 60, yRadius: 60)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 55,
                  color: NSColor(white: 0, alpha: 0.33).cgColor)
    NSColor.white.setFill()
    clip.fill()
    ctx.restoreGState()

    ctx.saveGState()
    clip.addClip()
    raw.draw(in: NSRect(x: x, y: y, width: shotW, height: shotH),
             from: .zero, operation: .sourceOver, fraction: 1)
    ctx.restoreGState()

    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(shot.out))
    print("wrote \(shot.out)")
}

for s in sets[locale]! { frame(s) }
