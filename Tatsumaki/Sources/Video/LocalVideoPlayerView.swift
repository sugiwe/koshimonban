import SwiftUI
import AVKit

/// ローカルの動画ファイルを再生する。
struct LocalVideoPlayerView: NSViewRepresentable {

    let path: String
    let state: VideoPlaybackState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .minimal
        view.videoGravity = .resizeAspect

        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            state.markFailed("動画ファイルが見つかりません: \(url.lastPathComponent)")
            return view
        }

        state.beginWaitingForPlayback()

        let player = AVPlayer(url: url)
        // システム音量に従う。アプリ側で勝手に上げない。
        player.volume = 1.0
        view.player = player
        context.coordinator.observe(player: player)
        player.play()
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) { }

    static func dismantleNSView(_ view: AVPlayerView, coordinator: Coordinator) {
        coordinator.stop()
        view.player?.pause()
        view.player = nil
    }

    final class Coordinator: NSObject {
        private let state: VideoPlaybackState
        private var statusObservation: NSKeyValueObservation?
        private var timeObserver: Any?
        private weak var player: AVPlayer?

        init(state: VideoPlaybackState) { self.state = state }

        func observe(player: AVPlayer) {
            self.player = player

            statusObservation = player.observe(\.currentItem?.status, options: [.new]) { [weak self] observed, _ in
                guard let self else { return }
                if observed.currentItem?.status == .failed {
                    let message = observed.currentItem?.error?.localizedDescription ?? "動画を再生できませんでした"
                    Task { @MainActor in self.state.markFailed(message) }
                }
            }

            // 実際に再生位置が進んだことを確認して初めて「再生できている」と扱う。
            // 読み込み成功だけでは、無音の静止画が出ている場合と区別がつかない。
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
            ) { [weak self] time in
                guard let self, time.seconds > 0 else { return }
                Task { @MainActor in self.state.markPlaying() }
            }
        }

        func stop() {
            statusObservation?.invalidate()
            statusObservation = nil
            if let timeObserver, let player {
                player.removeTimeObserver(timeObserver)
            }
            timeObserver = nil
        }
    }
}
