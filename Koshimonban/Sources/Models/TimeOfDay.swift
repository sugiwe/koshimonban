import Foundation

/// 「10:00」のような時刻。日付を持たない。
/// JSON では "HH:mm" の文字列として保存する（人間が直接開いて直せることを優先）。
struct TimeOfDay: Codable, Equatable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// 0:00 からの経過分。時刻の比較や発動グリッドの計算はすべてこれで行う。
    var minutesFromMidnight: Int { hour * 60 + minute }

    init?(minutesFromMidnight minutes: Int) {
        guard (0..<(24 * 60)).contains(minutes) else { return nil }
        self.init(hour: minutes / 60, minute: minutes % 60)
    }

    var displayString: String { String(format: "%02d:%02d", hour, minute) }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesFromMidnight < rhs.minutesFromMidnight
    }

    // MARK: Codable ("HH:mm" 文字列として読み書きする)

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = TimeOfDay(string: raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "時刻の書式が \"HH:mm\" ではありません: \(raw)")
            )
        }
        self = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(displayString)
    }

    init?(string: String) {
        let parts = string.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        self.init(hour: hour, minute: minute)
    }
}
