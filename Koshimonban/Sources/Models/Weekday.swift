import Foundation

/// 曜日。JSON では英字3文字で持つ（手で開いて直せることを優先）。
enum Weekday: String, Codable, CaseIterable, Identifiable, Comparable {
    case mon, tue, wed, thu, fri, sat, sun

    var id: String { rawValue }

    /// 1=月曜 … 7=日曜。スケジューラ側はこの番号で扱う。
    var index: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    init?(index: Int) {
        guard (1...7).contains(index) else { return nil }
        self = Self.allCases[index - 1]
    }

    var displayName: String {
        switch self {
        case .mon: "月"
        case .tue: "火"
        case .wed: "水"
        case .thu: "木"
        case .fri: "金"
        case .sat: "土"
        case .sun: "日"
        }
    }

    var isWeekend: Bool { self == .sat || self == .sun }

    static let weekdays: [Weekday] = [.mon, .tue, .wed, .thu, .fri]

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.index < rhs.index }
}
