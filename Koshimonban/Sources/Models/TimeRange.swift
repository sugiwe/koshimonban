import Foundation

/// 1日の中の時間の範囲。日をまたぐものは表せない（v1 の非対応方針のまま）。
struct TimeRange: Codable, Equatable, Hashable, Identifiable {
    var start: TimeOfDay
    var end: TimeOfDay

    /// 表示用。JSON には書き出さない。
    var id: String { "\(start.displayString)-\(end.displayString)" }

    init(start: TimeOfDay, end: TimeOfDay) {
        self.start = start
        self.end = end
    }

    enum CodingKeys: String, CodingKey { case start, end }

    var isValid: Bool { start < end }

    var displayString: String { "\(start.displayString)–\(end.displayString)" }

    // MARK: タイル（30分刻み）との相互変換
    //
    // 設定画面は時間割表のタイルを塗って編集するが、保存されるのはあくまで範囲。
    // スケジューラの処理も JSON の読みやすさも、タイル化の影響を受けないようにしている。

    static let slotMinutes = 30
    static let slotsPerDay = (24 * 60) / slotMinutes   // 48

    /// この範囲が覆うタイルの番号。
    /// 端が30分に揃っていない場合は外側に丸めるので、塗られた見た目が欠けない。
    var slotIndices: Range<Int> {
        let first = start.minutesFromMidnight / Self.slotMinutes
        let last = Int((Double(end.minutesFromMidnight) / Double(Self.slotMinutes)).rounded(.up))
        return first..<max(first + 1, last)
    }

    /// タイルの集合を、連続した範囲にまとめ直す。
    static func ranges(fromSlots slots: Set<Int>) -> [TimeRange] {
        let sorted = slots.filter { (0..<slotsPerDay).contains($0) }.sorted()
        guard !sorted.isEmpty else { return [] }

        var result: [TimeRange] = []
        var runStart = sorted[0]
        var previous = sorted[0]

        func closeRun() {
            guard let start = TimeOfDay(minutesFromMidnight: runStart * slotMinutes),
                  let end = TimeOfDay(minutesFromMidnight: (previous + 1) * slotMinutes)
            else { return }
            result.append(TimeRange(start: start, end: end))
        }

        for slot in sorted.dropFirst() {
            if slot == previous + 1 {
                previous = slot
            } else {
                closeRun()
                runStart = slot
                previous = slot
            }
        }
        closeRun()
        return result
    }

    static func slots(from ranges: [TimeRange]) -> Set<Int> {
        var slots: Set<Int> = []
        for range in ranges where range.isValid {
            slots.formUnion(range.slotIndices)
        }
        return slots
    }
}
