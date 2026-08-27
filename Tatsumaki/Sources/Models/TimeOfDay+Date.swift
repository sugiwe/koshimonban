import Foundation

/// SwiftUI の DatePicker は Date しか扱えないため、その日の日付に貼り付けて往復させる。
extension TimeOfDay {
    var asDate: Date {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: base) ?? base
    }

    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }
}

extension WorkBlock {
    mutating func setWeekday(_ weekday: Int, enabled: Bool) {
        var set = Set(weekdays)
        if enabled { set.insert(weekday) } else { set.remove(weekday) }
        weekdays = set.filter { (1...7).contains($0) }.sorted()
    }

    static let weekdayNames = ["月", "火", "水", "木", "金", "土", "日"]

    var weekdayDescription: String {
        guard !weekdays.isEmpty else { return "曜日が選ばれていません" }
        return weekdays.compactMap { index -> String? in
            guard (1...7).contains(index) else { return nil }
            return Self.weekdayNames[index - 1]
        }.joined(separator: "・")
    }
}
