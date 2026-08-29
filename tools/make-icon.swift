import AppKit

// 元画像から macOS 用のアプリアイコン一式を書き出す使い捨てスクリプト。
//
// **macOS は iOS と違い、アイコンの角丸を自動でマスクしてくれない。**
// 角丸は自分で焼き込み、その外側は透明にしておく必要がある。
// 外側が不透明なまま .icns にすると、Finder で「四角い板の中に角丸」という見た目になる。
//
// 元画像（tools/icon-source.png）は角丸の外側が黒で塗られているため、
// ここで絵の本体だけを切り出し、squircle でクリップして透明な余白を作る。

let arguments = CommandLine.arguments
guard arguments.count > 2 else {
    FileHandle.standardError.write("使い方: gen <元画像> <出力先ディレクトリ>\n".data(using: .utf8)!)
    exit(1)
}
let sourcePath = arguments[1]
let outputDirectory = arguments[2]
let sizes = [16, 32, 64, 128, 256, 512, 1024]

/// アイコン本体の周囲に空ける余白の割合。Apple の慣習に合わせている。
let marginRatio: CGFloat = 0.08
/// 角丸の半径。辺の長さに対する比率で、Apple の squircle に近い。
let cornerRatio: CGFloat = 0.2237

// MARK: 元画像の読み込み

guard let sourceImage = NSImage(contentsOfFile: sourcePath),
      let sourceCG = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("元画像を読み込めません: \(sourcePath)\n".data(using: .utf8)!)
    exit(1)
}

// MARK: 絵の本体がどこにあるかを調べる
//
// 元画像は角丸の外側が黒く塗られている。その黒を含めて縮小すると、
// せっかく透明にした余白の内側に黒い縁が残る。中央の行と列を走査して、
// 「黒でない画素」がどこから始まるかを見る。
// アイコンは正方形の中央に置かれている前提で、上下左右の余白は等しいものとして扱う。

func contentExtent(of image: CGImage, threshold: UInt8 = 24) -> CGRect {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: width * height * 4)

    guard let context = CGContext(data: &pixels,
                                  width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    func isContent(x: Int, y: Int) -> Bool {
        let offset = y * bytesPerRow + x * 4
        let alpha = pixels[offset + 3]
        if alpha <= 8 { return false }
        return pixels[offset] > threshold || pixels[offset + 1] > threshold || pixels[offset + 2] > threshold
    }

    // 中央の行を左右から詰めて、絵の左右の端を探す
    let middleRow = height / 2
    var left = 0
    while left < width && !isContent(x: left, y: middleRow) { left += 1 }
    var right = width - 1
    while right > left && !isContent(x: right, y: middleRow) { right -= 1 }

    // 中央の列で高さを測る
    let middleColumn = width / 2
    var bottom = 0
    while bottom < height && !isContent(x: middleColumn, y: bottom) { bottom += 1 }
    var top = height - 1
    while top > bottom && !isContent(x: middleColumn, y: top) { top -= 1 }

    guard right > left, top > bottom else {
        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    // アイコン本体は正方形なので、縦横で食い違ったら小さいほうを採る。
    // 食い違いは影やにじみを拾ったときに出る。
    //
    // **大きく見積もるより小さく見積もるほうが安全。** 大きく取ると元画像の黒い角が
    // クリップの内側に入り込んで縁が黒くにじむ。小さく取った場合は絵がわずかに
    // 拡大されるだけで済む。
    let side = min(CGFloat(right - left + 1), CGFloat(top - bottom + 1))
    return CGRect(x: (CGFloat(width) - side) / 2,
                  y: (CGFloat(height) - side) / 2,
                  width: side, height: side)
}

let content = contentExtent(of: sourceCG)
FileHandle.standardError.write(
    "元画像 \(sourceCG.width)x\(sourceCG.height) のうち、絵の本体は \(Int(content.width))x\(Int(content.height))\n"
        .data(using: .utf8)!)

// MARK: 書き出し

for size in sizes {
    let dimension = CGFloat(size)

    // NSImage の lockFocus に任せると Retina 環境で 2倍の実寸になることがある。
    // 画素数を指定した rep に直接描いて、必ず指定どおりの大きさにする。
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: size, pixelsHigh: size,
                                     bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0),
          let graphicsContext = NSGraphicsContext(bitmapImageRep: rep) else {
        FileHandle.standardError.write("\(size)px の描画先を作れません\n".data(using: .utf8)!)
        exit(1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    let context = graphicsContext.cgContext
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let margin = (dimension * marginRatio).rounded()
    let rect = CGRect(x: margin, y: margin,
                      width: dimension - margin * 2, height: dimension - margin * 2)
    let radius = rect.width * cornerRatio
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    context.saveGState()
    path.addClip()
    // クリップより少しだけ大きく描く。元画像の角丸の縁に残る黒い1〜2画素を切り落とすため。
    let overscan = max(1, rect.width * 0.006)
    let drawRect = rect.insetBy(dx: -overscan, dy: -overscan)
    sourceImage.draw(in: drawRect, from: content, operation: .sourceOver, fraction: 1.0)
    context.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("\(size)px を PNG にできません\n".data(using: .utf8)!)
        exit(1)
    }
    let url = URL(fileURLWithPath: "\(outputDirectory)/icon_\(size).png")
    do {
        try png.write(to: url)
    } catch {
        FileHandle.standardError.write("\(url.path) を書き出せません: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}
