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

    @Published private(set) var isVisible = false

    /// 休憩が決着したときに呼ばれる。Phase 3 で記録に繋ぐ。
    var onFinish: ((BreakResult, SkipReason?, Int, String?) -> Void)?

    private var windows: [OverlayWindow] = []
    private var session: BreakSession?
    private var video: VideoEntry?
    private var playbackState: VideoPlaybackState?
    private var screenChangeObserver: NSObjectProtocol?

    // MARK: 表示

    func present(breakSeconds: Int, skipUnlockSeconds: Int, video: VideoEntry?) {
        guard !isVisible else { return }

        self.video = video
        self.playbackState = video == nil ? nil : VideoPlaybackState()

        let session = BreakSession(breakSeconds: breakSeconds, skipUnlockSeconds: skipUnlockSeconds)
        session.videoTitle = video?.displayTitle
        session.onFinish = { [weak self] result, reason, shownSeconds in
            guard let self else { return }
            let videoTitle = self.session?.videoTitle
            self.dismiss()
            self.onFinish?(result, reason, shownSeconds, videoTitle)
        }
        self.session = session

        buildWindows(for: session)
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
        tearDownWindows()
        stopObservingScreenChanges()
        isVisible = false
    }

    // MARK: ウィンドウ

    private func buildWindows(for session: BreakSession) {
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
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func tearDownWindows() {
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
        }
        windows.removeAll()
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
                self.buildWindows(for: session)
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
