import AppKit

// アプリアイコンを生成する使い捨てスクリプト。
// 濃紺の squircle に、メニューバーと同じ figure.flexibility を白で載せる。

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let sizes = [16, 32, 64, 128, 256, 512, 1024]

func makeIcon(size: Int) -> NSImage {
    let dimension = CGFloat(size)
    let image = NSImage(size: NSSize(width: dimension, height: dimension))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // macOS のアイコンは周囲に余白を取る
    let inset = dimension * 0.08
    let rect = CGRect(x: inset, y: inset,
                      width: dimension - inset * 2, height: dimension - inset * 2)
    let radius = rect.width * 0.2237   // Apple の squircle に近い比率
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    context.saveGState()
    path.addClip()
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.13, green: 0.18, blue: 0.34, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.14, alpha: 1),
    ])
    gradient?.draw(in: rect, angle: -90)
    context.restoreGState()

    // 門の意匠。鳥居のように、笠木・貫・二本の柱で構成する。
    // 主役は犬なので、背景に沈む濃さに留める。
    context.saveGState()
    path.addClip()
    NSColor.white.withAlphaComponent(0.22).setFill()

    let gateWidth = rect.width * 0.80
    let gateLeft = rect.midX - gateWidth / 2
    let postWidth = rect.width * 0.075
    let lintelHeight = rect.height * 0.072
    let lintelY = rect.maxY - rect.height * 0.22
    let postBottom = rect.minY + rect.height * 0.08
    let overhang = rect.width * 0.055

    // 笠木（一番上の横木。両端が柱より外に張り出す）
    NSBezierPath(roundedRect: CGRect(x: gateLeft - overhang, y: lintelY,
                                     width: gateWidth + overhang * 2, height: lintelHeight),
                 xRadius: lintelHeight / 2, yRadius: lintelHeight / 2).fill()

    // 貫（笠木の下を通る細い横木）
    let beamHeight = lintelHeight * 0.52
    NSBezierPath(roundedRect: CGRect(x: gateLeft, y: lintelY - rect.height * 0.11,
                                     width: gateWidth, height: beamHeight),
                 xRadius: beamHeight / 2, yRadius: beamHeight / 2).fill()

    // 柱（左右）
    for x in [gateLeft, gateLeft + gateWidth - postWidth] {
        NSBezierPath(roundedRect: CGRect(x: x, y: postBottom,
                                         width: postWidth, height: lintelY - postBottom),
                     xRadius: postWidth / 2, yRadius: postWidth / 2).fill()
    }
    context.restoreGState()

    // 門の前に座る犬。
    // シンボルは黒で描かれるので、いったん単独の画像に描いてから白く着色する。
    // 背景の上で直接 sourceAtop を使うと、背景が不透明なため矩形全体が塗られてしまう。
    if let symbol = NSImage(systemSymbolName: "dog.fill", accessibilityDescription: nil) {
        let configuration = NSImage.SymbolConfiguration(pointSize: dimension * 0.34, weight: .regular)
        if let configured = symbol.withSymbolConfiguration(configuration) {
            let symbolSize = configured.size
            let tinted = NSImage(size: symbolSize)
            tinted.lockFocus()
            configured.draw(in: NSRect(origin: .zero, size: symbolSize))
            NSColor.white.set()
            NSRect(origin: .zero, size: symbolSize).fill(using: .sourceAtop)
            tinted.unlockFocus()

            let target = NSRect(x: (dimension - symbolSize.width) / 2,
                                y: rect.minY + rect.height * 0.17,
                                width: symbolSize.width, height: symbolSize.height)
            tinted.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

    image.unlockFocus()
    return image
}

for size in sizes {
    let image = makeIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { continue }
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent("icon_\(size).png")
    try? png.write(to: url)
    print("生成: \(url.lastPathComponent)")
}
