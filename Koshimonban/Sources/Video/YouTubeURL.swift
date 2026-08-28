import Foundation

/// YouTube の URL から動画 ID を取り出す。
///
/// 貼り付けられる URL の形は一つではないので、主要な形をまとめてここで吸収する。
/// ID そのものを貼られた場合も受け付ける。
enum YouTubeURL {

    /// ID として妥当な文字だけで構成されているか（11文字が標準だが長さは決め打ちしない）
    private static let allowedIDCharacters = CharacterSet(charactersIn:
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")

    static func videoID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // URL ではなく ID そのものを貼られた場合
        if !trimmed.contains("/"), !trimmed.contains("?"), isValidID(trimmed) {
            return trimmed
        }

        // スキームが無い URL（www.youtube.com/watch?v=...）も拾えるように補う
        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: normalized),
              let host = components.host?.lowercased()
        else { return nil }

        let path = components.path
        let segments = path.split(separator: "/").map(String.init)

        // youtu.be/ID
        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            return segments.first.flatMap { isValidID($0) ? $0 : nil }
        }

        guard host.contains("youtube.com") || host.contains("youtube-nocookie.com") else {
            return nil
        }

        // youtube.com/watch?v=ID
        if let v = components.queryItems?.first(where: { $0.name == "v" })?.value,
           isValidID(v) {
            return v
        }

        // youtube.com/embed/ID, /shorts/ID, /live/ID, /v/ID
        if segments.count >= 2,
           ["embed", "shorts", "live", "v"].contains(segments[0]),
           isValidID(segments[1]) {
            return segments[1]
        }

        return nil
    }

    static func isValidID(_ candidate: String) -> Bool {
        guard !candidate.isEmpty, candidate.count <= 32 else { return false }
        return candidate.unicodeScalars.allSatisfy { allowedIDCharacters.contains($0) }
    }

    /// 埋め込み用の URL。cookie を置かない nocookie ドメインを使う。
    static func embedURL(forID id: String) -> URL? {
        URL(string: "https://www.youtube-nocookie.com/embed/\(id)")
    }
}
