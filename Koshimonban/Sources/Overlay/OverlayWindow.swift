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

        // 暗さはウィンドウではなく SwiftUI 側で描く。門が左右から閉じる動きを見せるには、
        // 閉じきるまでの間だけ中央が透けている必要があるため。
        // 閉じきったあとは不透明の暗幕で覆われるので、下の画面は見えない。
        //
        // なお、透ける領域があってもクリックは奪える。OverlayRootView が
        // 「目には見えないがゼロではない濃さ」を全画面に敷いており、
        // macOS はそこを不透明とみなしてこのウィンドウにイベントを届ける。
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        setFrame(screen.frame, display: true)
    }
}
