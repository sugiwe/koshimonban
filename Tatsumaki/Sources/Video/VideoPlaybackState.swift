import Foundation
import Combine

/// 動画が実際に再生できているかを追跡する。
///
/// **単に WKWebView / AVPlayer の読み込みが成功したかでは足りない。**
/// 埋め込み禁止の動画、地域制限、自動再生のブロックは、いずれも
/// 「読み込み自体は成功」してしまうため、黙って黒い画面が出続けることになる。
/// 実際に再生が始まったことを確認できるまでは、失敗しうる状態として扱う。
@MainActor
final class VideoPlaybackState: ObservableObject {

    enum Status: Equatable {
        case loading
        case playing
        case failed(String)
    }

    /// 再生開始をこの秒数待って始まらなければ失敗とみなす。
    static let startTimeoutSeconds: TimeInterval = 5

    @Published private(set) var status: Status = .loading

    private var timeoutTask: Task<Void, Never>?

    var hasFailed: Bool {
        if case .failed = status { return true }
        return false
    }

    var failureReason: String? {
        if case .failed(let reason) = status { return reason }
        return nil
    }

    func beginWaitingForPlayback() {
        status = .loading
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.startTimeoutSeconds))
            guard !Task.isCancelled else { return }
            guard let self, self.status == .loading else { return }
            self.markFailed("再生が \(Int(Self.startTimeoutSeconds)) 秒以内に始まりませんでした")
        }
    }

    func markPlaying() {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard !hasFailed else { return }
        status = .playing
    }

    func markFailed(_ reason: String) {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard !hasFailed else { return }
        status = .failed(reason)
        NSLog("[Tatsumaki] 動画の再生に失敗: \(reason)")
    }

    func invalidate() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }
}
