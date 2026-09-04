import Foundation

extension TimeOfDay {
    /// 実際の日時から時刻部分だけを取り出す。記録に残す発動時刻などに使う。
    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }
}
