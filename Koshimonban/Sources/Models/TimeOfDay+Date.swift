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
