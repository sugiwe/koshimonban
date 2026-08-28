import Foundation

/// 1回の発動の記録。logs/YYYY-MM.json に保存する。
///
/// `id` は表示用で、JSON には書き出さない（仕様書のフォーマットを保つため）。
struct BreakRecord: Codable, Hashable, Identifiable {
    let id = UUID()

    /// 発動予定時刻
    var scheduledAt: TimeOfDay
    /// 実際の発動時刻。発動しなかった場合（missed / paused）は予定時刻と同じにする。
    var firedAt: TimeOfDay
    var result: BreakResult
    var skipReason: SkipReason?
    /// 実際に画面が出ていた秒数
    var shownSeconds: Int
    var videoTitle: String?

    enum CodingKeys: String, CodingKey {
        case scheduledAt, firedAt, result, skipReason, shownSeconds, videoTitle
    }

    init(scheduledAt: TimeOfDay, firedAt: TimeOfDay, result: BreakResult,
         skipReason: SkipReason? = nil, shownSeconds: Int = 0, videoTitle: String? = nil) {
        self.scheduledAt = scheduledAt
        self.firedAt = firedAt
        self.result = result
        self.skipReason = skipReason
        self.shownSeconds = shownSeconds
        self.videoTitle = videoTitle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let scheduled = try c.decodeIfPresent(TimeOfDay.self, forKey: .scheduledAt)
            ?? TimeOfDay(hour: 0, minute: 0)
        self.init(
            scheduledAt: scheduled,
            firedAt: try c.decodeIfPresent(TimeOfDay.self, forKey: .firedAt) ?? scheduled,
            result: try c.decodeIfPresent(BreakResult.self, forKey: .result) ?? .missed,
            skipReason: try c.decodeIfPresent(SkipReason.self, forKey: .skipReason),
            shownSeconds: try c.decodeIfPresent(Int.self, forKey: .shownSeconds) ?? 0,
            videoTitle: try c.decodeIfPresent(String.self, forKey: .videoTitle)
        )
    }
}
