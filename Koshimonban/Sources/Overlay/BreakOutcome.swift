import Foundation

/// 1回の休憩がどう終わったか。オーバーレイから記録側へ渡す。
struct BreakOutcome {
    let result: BreakResult
    let skipReason: SkipReason?
    /// 実際に画面が出ていた秒数
    let shownSeconds: Int
    let videoTitle: String?
    /// 発動予定時刻（0:00 からの経過秒）
    let scheduledSeconds: Int
    /// 実際に発動した時刻
    let firedAt: Date
}
