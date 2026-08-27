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

    // 竜巻を思わせる円弧を薄く重ねる
    context.saveGState()
    path.addClip()
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.07).cgColor)
    context.setLineWidth(dimension * 0.035)
    for index in 0..<3 {
        let scale = 0.78 - CGFloat(index) * 0.18
        let arcRect = CGRect(x: rect.midX - rect.width * scale / 2,
                             y: rect.midY - rect.height * scale / 2 + rect.height * CGFloat(index) * 0.12,
                             width: rect.width * scale, height: rect.height * scale * 0.42)
        context.strokeEllipse(in: arcRect)
    }
    context.restoreGState()

    // シンボルは黒で描かれるので、いったん単独の画像に描いてから白く着色する。
    // 背景の上で直接 sourceAtop を使うと、背景が不透明なため矩形全体が塗られてしまう。
    if let symbol = NSImage(systemSymbolName: "figure.flexibility", accessibilityDescription: nil) {
        let configuration = NSImage.SymbolConfiguration(pointSize: dimension * 0.52, weight: .regular)
        if let configured = symbol.withSymbolConfiguration(configuration) {
            let symbolSize = configured.size
            let tinted = NSImage(size: symbolSize)
            tinted.lockFocus()
            configured.draw(in: NSRect(origin: .zero, size: symbolSize))
            NSColor.white.set()
            NSRect(origin: .zero, size: symbolSize).fill(using: .sourceAtop)
            tinted.unlockFocus()

            let target = NSRect(x: (dimension - symbolSize.width) / 2,
                                y: (dimension - symbolSize.height) / 2,
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
