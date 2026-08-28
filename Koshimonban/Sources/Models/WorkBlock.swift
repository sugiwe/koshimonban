import Foundation

/// 作業時間帯。ストレッチを発動させたい時間の範囲。
struct WorkBlock: Codable, Identifiable, Equatable {
    var id: UUID
    var start: TimeOfDay
    var end: TimeOfDay
    /// 1=月曜 … 7=日曜。昇順で保持する。
    var weekdays: [Int]

    init(id: UUID = UUID(), start: TimeOfDay, end: TimeOfDay, weekdays: [Int]) {
        self.id = id
        self.start = start
        self.end = end
        self.weekdays = weekdays.filter { (1...7).contains($0) }.sorted()
    }

    /// 日付をまたぐ時間帯は v1 では非対応。設定画面でこれを弾く。
    var isValid: Bool { start < end }

    func includes(weekday: Int) -> Bool { weekdays.contains(weekday) }

    var displayString: String { "\(start.displayString)–\(end.displayString)" }

    // 欠けたキーがあっても既定値で読めるようにする（設定ファイルを手で編集されうるため）
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let start = try c.decodeIfPresent(TimeOfDay.self, forKey: .start) ?? TimeOfDay(hour: 10, minute: 0)
        let end = try c.decodeIfPresent(TimeOfDay.self, forKey: .end) ?? TimeOfDay(hour: 12, minute: 0)
        let weekdays = try c.decodeIfPresent([Int].self, forKey: .weekdays) ?? [1, 2, 3, 4, 5]
        self.init(id: id, start: start, end: end, weekdays: weekdays)
    }
}
