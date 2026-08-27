import Foundation

/// 休憩中に流す動画。0件でもアプリは動く（テキストとカウントダウンのみになる）。
struct VideoEntry: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case youtube
        case local

        var displayName: String {
            switch self {
            case .youtube: "YouTube"
            case .local:   "ローカルファイル"
            }
        }
    }

    var id: UUID
    var title: String
    var kind: Kind
    /// kind == .youtube のとき使う
    var url: String?
    /// kind == .local のとき使う
    var path: String?

    init(id: UUID = UUID(), title: String, kind: Kind, url: String? = nil, path: String? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.url = url
        self.path = path
    }

    var displayTitle: String { title.isEmpty ? "（無題）" : title }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            title: try c.decodeIfPresent(String.self, forKey: .title) ?? "",
            kind: try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .youtube,
            url: try c.decodeIfPresent(String.self, forKey: .url),
            path: try c.decodeIfPresent(String.self, forKey: .path)
        )
    }
}
