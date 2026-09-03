import AppKit

// Compose raw 1320x2868 simulator screenshots into App Store marketing frames:
// a brand-blue field, a short headline up top, the screenshot below with rounded
// corners and a soft shadow.
//
//   swift frame.swift <rawDir> <outDir> <locale>
//
// rawDir holds  <locale>-<name>.png  (name: home active summary place).

let W: CGFloat = 1320, H: CGFloat = 2868

struct Shot { let name: String; let headline: String }

let args = CommandLine.arguments
let rawDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let locale = args[3]

let sets: [String: [Shot]] = [
    "en": [
        Shot(name: "home",    headline: "Every town you drive through"),
        Shot(name: "active",  headline: "Know where you are, the moment you arrive"),
        Shot(name: "summary", headline: "A timeline of everywhere you passed"),
        Shot(name: "place",   headline: "Population and a line of history"),
    ],
    "tr": [
        Shot(name: "home",    headline: "Yolda geçtiğin her yer"),
        Shot(name: "active",  headline: "Girdiğin anda nerede olduğunu öğren"),
        Shot(name: "summary", headline: "Geçtiğin her yerin zaman çizelgesi"),
        Shot(name: "place",   headline: "Nüfusu ve kısa bir tarihçesi"),
    ],
]

func frame(_ shot: Shot) {
    let img = NSImage(size: NSSize(width: W, height: H))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    let grad = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(srgbRed: 0.09, green: 0.29, blue: 0.60, alpha: 1).cgColor,
            NSColor(srgbRed: 0.03, green: 0.15, blue: 0.37, alpha: 1).cgColor,
        ] as CFArray, locations: [0, 1]
    )!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])

    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineSpacing = 8
    let title = NSAttributedString(string: shot.headline, attributes: [
        .font: NSFont.systemFont(ofSize: 74, weight: .heavy),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
        .kern: 0.5,
    ])
    title.draw(with: NSRect(x: 90, y: H - 470, width: W - 180, height: 380),
               options: [.usesLineFragmentOrigin, .usesFontLeading])

    guard let raw = NSImage(contentsOf: rawDir.appendingPathComponent("\(locale)-\(shot.name).png")) else {
        fatalError("missing \(locale)-\(shot.name).png")
    }
    let shotW: CGFloat = 1120
    let shotH = H * (shotW / W)
    let x = (W - shotW) / 2
    let y = H - 500 - shotH

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
    let out = outDir.appendingPathComponent("\(locale)-\(shot.name).png")
    try! rep.representation(using: .png, properties: [:])!.write(to: out)
    print("wrote \(out.lastPathComponent)")
}

for s in sets[locale]! { frame(s) }
