import AppKit
import SwiftUI

/// 発動の予告。画面の隅に小さなウィンドウを出す。
///
/// `UserNotifications` を使わない理由:
/// 通知センターの通知は署名済みバンドルを前提とし、ローカルビルドでは権限ダイアログが
/// 出ないことがある。加えて通知は無視されやすく、このアプリの趣旨に合わない。
/// 自前ウィンドウなら権限リクエストも要らない。
@MainActor
final class PreNotifyController {

    static let shared = PreNotifyController()

    /// 予告を出しておく秒数の上限。これを過ぎたら自然に消す。
    private static let maxVisibleSeconds: TimeInterval = 20

    private var window: NSWindow?
    private var hideTimer: Timer?

    func show(secondsUntilBreak: Int) {
        dismiss()

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let size = CGSize(width: 300, height: 84)
        let margin: CGFloat = 24
        let frame = CGRect(
            x: screen.visibleFrame.maxX - size.width - margin,
            y: screen.visibleFrame.maxY - size.height - margin,
            width: size.width, height: size.height
        )

        let window = NSWindow(contentRect: frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        // 予告は見せるだけ。作業中のクリックを奪わない。
        window.ignoresMouseEvents = true

        let hosting = NSHostingView(rootView: PreNotifyView(seconds: secondsUntilBreak))
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        // フォーカスは奪わない。作業を止めるのは本番の発動だけでいい。
        window.orderFrontRegardless()
        self.window = window

        let visibleSeconds = min(Self.maxVisibleSeconds, TimeInterval(max(3, secondsUntilBreak)))
        let timer = Timer(timeInterval: visibleSeconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer
    }

    func dismiss() {
        hideTimer?.invalidate()
        hideTimer = nil
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
    }
}

private struct PreNotifyView: View {
    let seconds: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.flexibility")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 3) {
                Text("まもなく休憩です")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(remainingText)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.09, green: 0.10, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var remainingText: String {
        if seconds < 60 { return "あと \(seconds) 秒 — 区切りをつけておいてください" }
        let minutes = Int((Double(seconds) / 60).rounded())
        return "あと \(minutes) 分 — 区切りをつけておいてください"
    }
}
