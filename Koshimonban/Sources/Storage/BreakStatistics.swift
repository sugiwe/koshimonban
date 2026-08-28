import Foundation

/// 記録の集計。
///
/// 集計の目的は達成を褒めることではなく、**サボりのパターンを可視化すること**。
/// スキップの回数と理由は必ず前に出す。
struct BreakStatistics {

    struct DaySummary: Identifiable {
        var id: Date { date }
        let date: Date
        let achieved: Int
        let total: Int
        let skipped: Int

        /// 記録が無い日と、記録があって0件の日を区別する
        var hasRecords: Bool { total > 0 }
        var rate: Double { total > 0 ? Double(achieved) / Double(total) : 0 }
    }

    let days: [DaySummary]
    let skipReasonCounts: [SkipReason: Int]
    /// 理由を選ばずにスキップした回数
    let skipWithoutReason: Int

    var totalAchieved: Int { days.reduce(0) { $0 + $1.achieved } }
    var totalCount: Int { days.reduce(0) { $0 + $1.total } }
    var totalSkipped: Int { days.reduce(0) { $0 + $1.skipped } }
    var rate: Double { totalCount > 0 ? Double(totalAchieved) / Double(totalCount) : 0 }

    var ratePercentText: String {
        totalCount > 0 ? "\(Int((rate * 100).rounded()))%" : "—"
    }

    /// 直近 `dayCount` 日ぶんを集計する（今日を含む）。
    @MainActor
    static func build(from store: LogStore, dayCount: Int, calendar: Calendar = .current) -> BreakStatistics {
        var days: [DaySummary] = []
        var reasonCounts: [SkipReason: Int] = [:]
        var withoutReason = 0

        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let records = store.records(for: date)

            let counted = records.filter { $0.result.countsInTotal }
            let achieved = counted.filter { $0.result.countsAsAchieved }.count
            let skipped = records.filter { $0.result == .skipped }

            for record in skipped {
                if let reason = record.skipReason {
                    reasonCounts[reason, default: 0] += 1
                } else {
                    withoutReason += 1
                }
            }

            days.append(DaySummary(date: calendar.startOfDay(for: date),
                                   achieved: achieved,
                                   total: counted.count,
                                   skipped: skipped.count))
        }

        return BreakStatistics(days: days,
                               skipReasonCounts: reasonCounts,
                               skipWithoutReason: withoutReason)
    }
}
