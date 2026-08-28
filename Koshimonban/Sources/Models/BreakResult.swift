import Foundation

/// 1回の発動がどう終わったか。記録（Phase 3）と、発動しなかった理由の両方を表す。
enum BreakResult: String, Codable, CaseIterable {
    /// 最後までやった、または残り30秒未満で「終わった」を押した
    case completed
    /// 「スキップ」を押した
    case skipped
    /// 残り30秒以上を残して「終わった」を押した
    case short
    /// スリープ・画面ロックのまま作業時間帯が終わり、発動できなかった
    case missed
    /// 一時停止中に発動時刻が来た
    case paused

    var displayName: String {
        switch self {
        case .completed: "完了"
        case .skipped:   "スキップ"
        case .short:     "短縮"
        case .missed:    "取りこぼし"
        case .paused:    "一時停止"
        }
    }

    /// 達成率の分子に数えるか。
    /// 「短縮」は立ち上がってはいるので達成に含める。「取りこぼし」「一時停止」は
    /// 本人の意思ではないので分母からも外す（3.5 の集計で使う）。
    var countsAsAchieved: Bool {
        switch self {
        case .completed, .short: true
        case .skipped, .missed, .paused: false
        }
    }

    /// 達成率の分母に数えるか。
    var countsInTotal: Bool {
        switch self {
        case .completed, .short, .skipped: true
        case .missed, .paused: false
        }
    }
}
