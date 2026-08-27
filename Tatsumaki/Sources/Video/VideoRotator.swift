import Foundation

/// 発動ごとに動画を切り替える。
///
/// 同じ動画が続くと「またこれか」で流し見になるため、前回と同じものは避ける。
/// 登録が1件しかない場合はどうしようもないのでそのまま返す。
@MainActor
final class VideoRotator {

    static let shared = VideoRotator()

    /// 直前に選んだ動画。アプリを再起動すると忘れるが、
    /// そこまでディスクに残す価値のある情報ではない。
    private var lastPlayedID: UUID?

    func next(from videos: [VideoEntry]) -> VideoEntry? {
        guard !videos.isEmpty else { return nil }
        guard videos.count > 1 else {
            lastPlayedID = videos[0].id
            return videos[0]
        }

        let startIndex: Int
        if let lastPlayedID, let index = videos.firstIndex(where: { $0.id == lastPlayedID }) {
            startIndex = (index + 1) % videos.count
        } else {
            startIndex = 0
        }

        let chosen = videos[startIndex]
        lastPlayedID = chosen.id
        return chosen
    }

    /// テストや設定変更時に履歴を捨てる
    func reset() { lastPlayedID = nil }
}
