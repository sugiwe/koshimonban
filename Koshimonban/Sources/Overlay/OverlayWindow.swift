import AppKit

/// 休憩中に画面を覆うウィンドウ。
///
/// スパイク検証（Phase -1）で macOS 15.6.1 での挙動を確認済み。
/// 変更するときは `spike/` の検証アプリで再確認すること。
final class OverlayWindow: NSWindow {

    /// borderless なウィンドウは既定で key window になれない。
    /// ここを上書きしないと「画面は覆えているのにタイプは下のアプリに通る」状態になる。
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Esc でオーバーレイを閉じさせない。
    /// 反射で消せてしまうと、摩擦を設計した意味がなくなる。
    override func cancelOperation(_ sender: Any?) { }

    convenience init(screen: NSScreen) {
        self.init(contentRect: screen.frame,
                  styleMask: [.borderless],
                  backing: .buffered,
                  defer: false)

        // スクリーンセーバーより上。フルスクリーンのアプリの上にも出る。
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        // 全 Space に出す。この組み合わせなら Space は切り替わらない（検証済み）。
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 半透明にすると下の画面が見えて作業を続けようとするため、不透明にする。
        isOpaque = true
        backgroundColor = NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.10, alpha: 1.0)
        hasShadow = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        setFrame(screen.frame, display: true)
    }
}
