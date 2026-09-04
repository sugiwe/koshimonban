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

    /// 門が左右から閉じきるまでの時間。
    ///
    /// **この間もウィンドウは最初から全画面に立っていて、入力を奪っている。**
    /// 透けているのは見た目だけで、門としての機能は0秒目から効いている。
    /// ここを「表示を遅らせる」実装にすると、その隙に作業を続けられてしまう。
    static let gateCloseSeconds: TimeInterval = 0.45
    /// 作業へ戻るときに門が開く時間。閉じるときよりやや速く。
    static let gateOpenSeconds: TimeInterval = 0.35
    /// 門が閉じきってから中身が現れるまで / 中身が消えてから門が開くまで。
    static let contentFadeInSeconds: TimeInterval = 0.25
    static let contentFadeOutSeconds: TimeInterval = 0.15

    @Published private(set) var isVisible = false

    /// 休憩が決着したときに呼ばれる。Phase 3 で記録に繋ぐ。
    var onFinish: ((BreakOutcome) -> Void)?

    private var windows: [OverlayWindow] = []
    private var session: BreakSession?
    private var video: VideoEntry?
    private var playbackState: VideoPlaybackState?
    private var scheduledSeconds = 0
    private var firedAt = Date()
    /// 全ディスプレイで同じ動きをさせるため、1回の休憩につき1つを共有する。
    private var gate: GateAnimation?
    /// 門の開閉を進めている Task。
    /// 閉じている最中に次の指示が来たら、前のものを止めてから始める。
    /// 保持しないでおくと、閉じる Task と開く Task が同じ GateAnimation を奪い合う。
    private var gateTask: Task<Void, Never>?
    /// 門を開いてウィンドウを片付け終えるまで true。
    /// `isVisible` は dismiss の時点で false になるが、実際のウィンドウは
    /// 0.5 秒ほど画面に残る。その隙間に次の発動を受け付けると、
    /// 古いウィンドウが入力を奪ったまま新しいオーバーレイが作られてしまう。
    private var isTearingDown = false
    private var screenChangeObserver: NSObjectProtocol?

    // MARK: 表示

    func present(breakSeconds: Int, skipUnlockSeconds: Int, video: VideoEntry?,
                 scheduledSeconds: Int, firedAt: Date = Date()) {
        guard !isVisible, !isTearingDown else { return }

        self.scheduledSeconds = scheduledSeconds
        self.firedAt = firedAt
        self.video = video
        self.playbackState = video == nil ? nil : VideoPlaybackState()

        let session = BreakSession(breakSeconds: breakSeconds, skipUnlockSeconds: skipUnlockSeconds)
        session.onFinish = { [weak self] result, reason, shownSeconds in
            guard let self else { return }
            let outcome = BreakOutcome(
                result: result,
                skipReason: reason,
                shownSeconds: shownSeconds,
                videoTitle: video?.displayTitle,
                scheduledSeconds: self.scheduledSeconds,
                firedAt: self.firedAt
            )
            self.dismiss()
            self.onFinish?(outcome)
        }
        self.session = session

        let gate = GateAnimation()
        self.gate = gate

        buildWindows(for: session, gate: gate)
        session.start()
        isVisible = true

        observeScreenChanges()
        takeFocus()
        closeGate(gate)
    }

    func dismiss() {
        session?.invalidate()
        session = nil
        playbackState?.invalidate()
        playbackState = nil
        video = nil
        stopObservingScreenChanges()
        isVisible = false
        openGateAndTearDownWindows()
    }

    // MARK: ウィンドウ

    /// ディスプレイの抜き差しで作り直す場合、`gate` はすでに閉じた状態なので、
    /// 新しいウィンドウは最初から閉じた見た目で出る。
    /// 覆えていない画面を一瞬でも作らないため、そこでは開閉の動きを付け直さない。
    private func buildWindows(for session: BreakSession, gate: GateAnimation) {
        tearDownWindows()

        // メインディスプレイ（NSScreen.main はキーウィンドウのある画面を指すため、
        // 表示前の時点では screens.first = メニューバーのある画面を主画面として扱う）
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let window = OverlayWindow(screen: screen)
            let isPrimary = (index == 0)
            let hosting = NSHostingView(
                rootView: OverlayRootView(session: session,
                                          gate: gate,
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

    /// 門を閉じ、閉じきってから中身を出す。
    private func closeGate(_ gate: GateAnimation) {
        gateTask?.cancel()
        gateTask = Task { @MainActor in
            // 開いた状態を1フレーム描いてから閉じ始める。
            // 間を置かずに値を変えると、SwiftUI が初期状態を描く前に確定してしまい、
            // 最初から閉じた状態で出てしまう。
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: Self.gateCloseSeconds)) {
                gate.isClosed = true
            }
            try? await Task.sleep(for: .seconds(Self.gateCloseSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: Self.contentFadeInSeconds)) {
                gate.showsContent = true
            }
        }
    }

    /// 中身を消し、門を開いてから片付ける。
    ///
    /// 片付ける対象を先に取り出して `windows` を空にしておくのは、
    /// 開いている最中に次の発動が来た場合に、新しいウィンドウまで巻き添えで
    /// 消されるのを防ぐため。
    private func openGateAndTearDownWindows() {
        let closing = windows
        windows.removeAll()
        let gate = self.gate
        self.gate = nil
        guard !closing.isEmpty else { return }

        isTearingDown = true
        gateTask?.cancel()
        gateTask = Task { @MainActor in
            // 片付けはキャンセルされても必ず最後まで走らせる。
            // 途中で止まると、画面を覆ったままのウィンドウが残る。
            defer {
                for window in closing {
                    window.orderOut(nil)
                    window.contentView = nil
                }
                self.isTearingDown = false
            }
            if let gate {
                withAnimation(.easeOut(duration: Self.contentFadeOutSeconds)) {
                    gate.showsContent = false
                }
                try? await Task.sleep(for: .seconds(Self.contentFadeOutSeconds))
                withAnimation(.easeIn(duration: Self.gateOpenSeconds)) {
                    gate.isClosed = false
                }
                try? await Task.sleep(for: .seconds(Self.gateOpenSeconds))
            }
        }
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
                guard let gate = self.gate else { return }
                self.buildWindows(for: session, gate: gate)
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
