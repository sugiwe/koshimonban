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

    var displayName: String {
        switch self {
        case .meeting:   "MTG直前"
        case .focused:   "集中してる"
        case .notInMood: "気分じゃない"
        }
    }
}
