import Foundation

/// 曜日ごとの作業時間帯。
///
/// 「時間帯に曜日を紐づける」のではなく「曜日に時間帯を紐づける」形にしている。
/// リモートワークでは曜日固定の定例 MTG が多く、
/// 「月曜はこの時間帯、火曜はこの時間帯」と組み立てる方が実態に合うため。
struct WeekSchedule: Codable, Equatable {

    private var days: [Weekday: [TimeRange]]

    init(days: [Weekday: [TimeRange]] = [:]) {
        self.days = days
    }

    subscript(weekday: Weekday) -> [TimeRange] {
        get { days[weekday] ?? [] }
        set { days[weekday] = newValue.filter { $0.isValid }.sorted { $0.start < $1.start } }
    }

    subscript(index index: Int) -> [TimeRange] {
        guard let weekday = Weekday(index: index) else { return [] }
        return self[weekday]
    }

    var isEmpty: Bool { Weekday.allCases.allSatisfy { self[$0].isEmpty } }

    var totalRangeCount: Int { Weekday.allCases.reduce(0) { $0 + self[$1].count } }

    // MARK: タイルとの相互変換

    func slots(for weekday: Weekday) -> Set<Int> {
        TimeRange.slots(from: self[weekday])
    }

    mutating func setSlots(_ slots: Set<Int>, for weekday: Weekday) {
        self[weekday] = TimeRange.ranges(fromSlots: slots)
    }

    // MARK: 移行

    /// v1 の `workBlocks`（時間帯 + 有効な曜日の集合）から作る。
    /// 1つの時間帯が複数曜日に紐づいていたものを、曜日ごとに複製する。
    static func migrating(from blocks: [LegacyWorkBlock]) -> WeekSchedule {
        var schedule = WeekSchedule()
        for weekday in Weekday.allCases {
            let ranges = blocks
                .filter { $0.isValid && $0.weekdays.contains(weekday.index) }
                .map { TimeRange(start: $0.start, end: $0.end) }
            schedule[weekday] = ranges
        }
        return schedule
    }

    // MARK: Codable
    //
    // JSON では曜日名をキーにした素直な形にする。手で開いて直せることを優先。
    // 空の曜日も書き出しておくと、どこに何を書けばよいか見て分かる。

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DayKey.self)
        var days: [Weekday: [TimeRange]] = [:]
        for weekday in Weekday.allCases {
            guard let key = DayKey(stringValue: weekday.rawValue) else { continue }
            let ranges = try container.decodeIfPresent([TimeRange].self, forKey: key) ?? []
            days[weekday] = ranges.filter { $0.isValid }.sorted { $0.start < $1.start }
        }
        self.init(days: days)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DayKey.self)
        for weekday in Weekday.allCases {
            guard let key = DayKey(stringValue: weekday.rawValue) else { continue }
            try container.encode(self[weekday], forKey: key)
        }
    }

    private struct DayKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}
