import Foundation

/// 発動の結果を記録に落とす。
///
/// **デバッグモード中は一切記録しない。**
/// 秒単位で何十回も発動させながら開発するため、記録に混ざると実データが使い物にならなくなる。
/// ヒートマップの見た目を確認したいときは、ダミーデータ生成を使う。
@MainActor
enum BreakRecorder {

    static var isRecordingEnabled: Bool {
        !SettingsStore.shared.settings.debugMode
    }

    /// 休憩が終わったとき
    static func record(_ outcome: BreakOutcome) {
        guard isRecordingEnabled else { return }
        let record = BreakRecord(
            scheduledAt: timeOfDay(fromSeconds: outcome.scheduledSeconds),
            firedAt: timeOfDay(from: outcome.firedAt),
            result: outcome.result,
            skipReason: outcome.skipReason,
            shownSeconds: outcome.shownSeconds,
            videoTitle: outcome.videoTitle
        )
        LogStore.shared.append(record, on: outcome.firedAt)
    }

    /// 発動できなかったとき（取りこぼし・一時停止）
    static func record(slot: ScheduleGrid.Slot, result: BreakResult, at date: Date) {
        guard isRecordingEnabled else { return }
        let scheduled = timeOfDay(fromSeconds: slot.at)
        let record = BreakRecord(
            scheduledAt: scheduled,
            firedAt: scheduled,   // 発動していないので予定時刻をそのまま入れる
            result: result,
            skipReason: nil,
            shownSeconds: 0,
            videoTitle: nil
        )
        LogStore.shared.append(record, on: date)
    }

    // MARK: 変換

    private static func timeOfDay(fromSeconds seconds: Int) -> TimeOfDay {
        let normalized = ScheduleGrid.normalized(seconds)
        return TimeOfDay(hour: normalized / 3600, minute: (normalized % 3600) / 60)
    }

    private static func timeOfDay(from date: Date) -> TimeOfDay {
        TimeOfDay(date: date)
    }

    /// メニューバーに出す当日の達成状況（達成数 / 今日の発動予定数）
    static func todayProgress() -> (achieved: Int, planned: Int) {
        let records = LogStore.shared.records(for: Date())
        let achieved = records.filter { $0.result.countsAsAchieved }.count
        let planned = ScheduleGrid.slots(settings: SettingsStore.shared.settings, date: Date()).count
        return (achieved, planned)
    }
}
