import Foundation

/// スキップの理由。
///
/// 理由を選ばせるのは分析のためというより、**スキップを無自覚に行わせないため**。
/// 「なぜ今サボるのか」を一度言語化させることが摩擦になる。
enum SkipReason: String, Codable, CaseIterable, Identifiable {
    case meeting
    case focused
    case notInMood

    var id: String { rawValue }

    /// 表示だけを変えること。`rawValue` は記録の JSON にそのまま書き込まれているため、
    /// 変えると過去の記録が読めなくなる。
    var displayName: String {
        switch self {
        case .meeting:   "MTG直前なので🧑‍💻"
        case .focused:   "今ノってるので🔥"
        case .notInMood: "気分じゃない🙂‍↔️"
        }
    }
}
