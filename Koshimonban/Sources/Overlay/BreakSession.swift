import Foundation
import Combine

/// 1回の休憩の進行状態。オーバーレイの各画面はこれを共有して見る。
@MainActor
final class BreakSession: ObservableObject {

    enum Phase {
        case running
        /// スキップを押した直後。理由を選ばせている。
        case choosingSkipReason
        case finished
    }

    /// 「終わった」を押したとき、これ以上残っていたら「短縮」として記録する。
    static let shortThresholdSeconds = 30

    /// 動画を出すまでに挟む前置きの秒数（3 → 2 → 1）。
    ///
    /// 暗転した直後に動画が鳴り出すのが唐突だったため、身構える間を置く。
    /// **これは見せ方だけの話で、休憩そのものは 0 秒目から進んでいる。**
    /// 前置きのぶん休憩を延ばす作りにすると、記録に残る休憩時間の意味が変わってしまう。
    static let videoLeadInSeconds = 3
    /// これ以下の短い休憩では前置きを入れない。休憩に占める前置きの割合が大きくなりすぎるため。
    static let minimumBreakForLeadInSeconds = 10

    @Published private(set) var phase: Phase = .running
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var skipUnlockRemaining: Int
    /// 動画が出るまでの残り秒数。0 になったら動画に差し替える。前置きなしの場合は最初から 0。
    @Published private(set) var videoLeadInRemaining: Int

    let totalSeconds: Int
    let startedAt: Date
    /// スキップが解禁されるまでの秒数（初期値）。経過時間から残りを再計算するために保持する。
    private let skipUnlockSeconds: Int
    /// Phase 2 で再生した動画のタイトルが入る
    var videoTitle: String?

    /// 決着したときに1度だけ呼ばれる。
    var onFinish: ((BreakResult, SkipReason?, Int) -> Void)?

    private var timer: Timer?
    private let tickInterval: TimeInterval = 0.25

    init(breakSeconds: Int, skipUnlockSeconds: Int, startedAt: Date = Date()) {
        let total = max(1, breakSeconds)
        self.totalSeconds = total
        self.remainingSeconds = total
        self.skipUnlockRemaining = max(0, skipUnlockSeconds)
        self.skipUnlockSeconds = max(0, skipUnlockSeconds)
        self.videoLeadInRemaining = total > Self.minimumBreakForLeadInSeconds ? Self.videoLeadInSeconds : 0
        self.startedAt = startedAt
    }

    // MARK: 進行

    func start() {
        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard phase != .finished else { return }

        // 経過時間は Date から計算する。Timer の発火回数を数えると、
        // 負荷やスリープでズレが蓄積するため。
        let elapsed = Date().timeIntervalSince(startedAt)

        skipUnlockRemaining = max(0, Int(ceil(Double(skipUnlockSeconds) - elapsed)))

        // 0 になったら二度と戻さない。前置きなしで始まった休憩をここで復活させないため。
        if videoLeadInRemaining > 0 {
            videoLeadInRemaining = max(0, Int(ceil(Double(Self.videoLeadInSeconds) - elapsed)))
        }

        let remaining = max(0, Int(ceil(Double(totalSeconds) - elapsed)))
        if remaining != remainingSeconds { remainingSeconds = remaining }

        // 理由の選択中でもカウントダウンが 0 になったら完了として閉じる。
        // 閉じないでおくと、選択の途中で離席した場合にオーバーレイが永久に残り、
        // ただの画面ロックになってしまうため。休憩時間は実際に経過しているので
        // 記録としても completed が正しい。
        if remaining <= 0 {
            finish(result: .completed, reason: nil)
        }
    }

    var canSkip: Bool { skipUnlockRemaining <= 0 }

    var elapsedSeconds: Int { max(0, Int(Date().timeIntervalSince(startedAt))) }

    var progress: Double {
        guard totalSeconds > 0 else { return 1 }
        return 1 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    var countdownText: String {
        String(format: "%d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    // MARK: 操作

    /// 「終わった」。残りが多いまま押した場合は「短縮」として記録する。
    func markDone() {
        guard phase == .running else { return }
        let result: BreakResult = remainingSeconds >= Self.shortThresholdSeconds ? .short : .completed
        finish(result: result, reason: nil)
    }

    /// 「スキップ」。すぐには決着させず、理由を選ばせる。
    func requestSkip() {
        guard phase == .running, canSkip else { return }
        phase = .choosingSkipReason
    }

    func confirmSkip(reason: SkipReason?) {
        guard phase == .choosingSkipReason else { return }
        finish(result: .skipped, reason: reason)
    }

    func cancelSkip() {
        guard phase == .choosingSkipReason else { return }
        phase = .running
    }

    private func finish(result: BreakResult, reason: SkipReason?) {
        guard phase != .finished else { return }
        phase = .finished
        timer?.invalidate()
        timer = nil
        onFinish?(result, reason, elapsedSeconds)
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}
