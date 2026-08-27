import SwiftUI

/// 休憩中の動画表示。再生できなかった場合はテキストに退避する。
///
/// **動画が出ないせいで休憩そのものが流れるのが最悪**なので、
/// 失敗しても休憩は必ず成立させる。
struct BreakVideoView: View {
    let video: VideoEntry
    @ObservedObject var state: VideoPlaybackState

    var body: some View {
        ZStack {
            if state.hasFailed {
                FallbackView(reason: state.failureReason)
            } else {
                switch video.kind {
                case .youtube:
                    if let id = video.url.flatMap({ YouTubeURL.videoID(from: $0) }) {
                        YouTubePlayerView(videoID: id, state: state)
                    } else {
                        FallbackView(reason: "YouTube の URL から動画 ID を読み取れませんでした")
                            .onAppear { state.markFailed("URL を解釈できません") }
                    }
                case .local:
                    if let path = video.path, !path.isEmpty {
                        LocalVideoPlayerView(path: path, state: state)
                    } else {
                        FallbackView(reason: "ファイルのパスが設定されていません")
                            .onAppear { state.markFailed("パス未設定") }
                    }
                }

                if state.status == .loading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct FallbackView: View {
    let reason: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.flexibility")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.white.opacity(0.35))
            Text("肩を回して、腰を伸ばしましょう")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            if let reason {
                Text("（動画を再生できませんでした: \(reason)）")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.04))
    }
}
