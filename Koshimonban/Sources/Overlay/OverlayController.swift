import AppKit
import SwiftUI
import Combine

/// 全ディスプレイにオーバーレイを出し、休憩の決着まで面倒を見る。
///
/// 外部ディスプレイのサブ画面だけ作業が続けられると意味がないため、
/// 接続されているすべての画面を覆う。
@MainActor
final class OverlayController: ObservableObject {

    static let shared = OverlayController()

    /// 画面を覆いきるまでの時間。
    ///
    /// **フェード中もウィンドウは最初から全画面に立っていて、入力を奪っている。**
    /// 透けているのは見た目だけで、門としての機能は0秒目から効いている。
    /// ここを「表示を遅らせる」実装にすると、その隙に作業を続けられてしまう。
    static let fadeInSeconds: TimeInterval = 0.35
    /// 作業へ戻るときも同じ速さで引く。
    static let fadeOutSeconds: TimeInterval = 0.35

    @Published private(set) var isVisible = false

    /// 休憩が決着したときに呼ばれる。Phase 3 で記録に繋ぐ。
    var onFinish: ((BreakOutcome) -> Void)?

    private var windows: [OverlayWindow] = []
    private var session: BreakSession?
    private var video: VideoEntry?
    private var playbackState: VideoPlaybackState?
    private var scheduledSeconds = 0
    private var firedAt = Date()
    private var screenChangeObserver: NSObjectProtocol?

    // MARK: 表示

    func present(breakSeconds: Int, skipUnlockSeconds: Int, video: VideoEntry?,
                 scheduledSeconds: Int, firedAt: Date = Date()) {
        guard !isVisible else { return }

        self.scheduledSeconds = scheduledSeconds
        self.firedAt = firedAt
        self.video = video
        self.playbackState = video == nil ? nil : VideoPlaybackState()

        let session = BreakSession(breakSeconds: breakSeconds, skipUnlockSeconds: skipUnlockSeconds)
        session.videoTitle = video?.displayTitle
        session.onFinish = { [weak self] result, reason, shownSeconds in
            guard let self else { return }
            let outcome = BreakOutcome(
                result: result,
                skipReason: reason,
                shownSeconds: shownSeconds,
                videoTitle: self.session?.videoTitle,
                scheduledSeconds: self.scheduledSeconds,
                firedAt: self.firedAt
            )
            self.dismiss()
            self.onFinish?(outcome)
        }
        self.session = session

        buildWindows(for: session, animated: true)
        session.start()
        isVisible = true

        observeScreenChanges()
        takeFocus()
    }

    func dismiss() {
        session?.invalidate()
        session = nil
        playbackState?.invalidate()
        playbackState = nil
        video = nil
        stopObservingScreenChanges()
        isVisible = false
        fadeOutAndTearDownWindows()
    }

    // MARK: ウィンドウ

    /// - Parameter animated: 発動時は薄く現れる。ディスプレイの抜き差しで作り直すときは
    ///   すでに休憩中なので、覆えていない画面を一瞬でも作らないよう即座に出す。
    private func buildWindows(for session: BreakSession, animated: Bool) {
        tearDownWindows()

        // メインディスプレイ（NSScreen.main はキーウィンドウのある画面を指すため、
        // 表示前の時点では screens.first = メニューバーのある画面を主画面として扱う）
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let window = OverlayWindow(screen: screen)
            let isPrimary = (index == 0)
            let hosting = NSHostingView(
                rootView: OverlayRootView(session: session,
                                          isPrimary: isPrimary,
                                          video: video,
                                          playbackState: playbackState)
            )
            hosting.frame = window.contentLayoutRect
            hosting.autoresizingMask = [.width, .height]
            window.contentView = hosting
            window.alphaValue = animated ? 0 : 1
            window.orderFrontRegardless()
            windows.append(window)
        }

        guard animated else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInSeconds
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for window in windows {
                window.animator().alphaValue = 1
            }
        }
    }

    private func tearDownWindows() {
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
        }
        windows.removeAll()
    }

    /// 薄くしてから片付ける。
    ///
    /// 片付ける対象を先に取り出して `windows` を空にしておくのは、
    /// フェード中に次の発動が来た場合に、新しいウィンドウまで巻き添えで
    /// 消されるのを防ぐため。
    private func fadeOutAndTearDownWindows() {
        let closing = windows
        windows.removeAll()
        guard !closing.isEmpty else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeOutSeconds
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in closing {
                window.animator().alphaValue = 0
            }
        }, completionHandler: {
            MainActor.assumeIsolated {
                for window in closing {
                    window.orderOut(nil)
                    window.contentView = nil
                }
            }
        })
    }

    /// フォーカスを奪う。
    /// `NSApp.activate(ignoringOtherApps:)` は macOS 14 で deprecated のため使わない。
    private func takeFocus() {
        NSApp.activate()
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        windows.first?.makeKeyAndOrderFront(nil)
    }

    // MARK: ディスプレイの抜き差し

    private func observeScreenChanges() {
        guard screenChangeObserver == nil else { return }
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible, let session = self.session else { return }
                // 休憩中にディスプレイが抜き差しされた場合、覆えていない画面が
                // 残らないようウィンドウを作り直す。セッション自体は引き継ぐ。
                self.buildWindows(for: session, animated: false)
                self.takeFocus()
            }
        }
    }

    private func stopObservingScreenChanges() {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
        screenChangeObserver = nil
    }
}
