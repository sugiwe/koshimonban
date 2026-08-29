import SwiftUI

struct OverlayRootView: View {
    @ObservedObject var session: BreakSession
    let isPrimary: Bool
    let video: VideoEntry?
    let playbackState: VideoPlaybackState?

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.10).ignoresSafeArea()
            if isPrimary {
                PrimaryOverlayView(session: session, video: video, playbackState: playbackState)
            } else {
                SecondaryOverlayView(session: session)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// メインディスプレイ側。カウントダウン・動画・ボタン。
private struct PrimaryOverlayView: View {
    @ObservedObject var session: BreakSession
    let video: VideoEntry?
    let playbackState: VideoPlaybackState?

    /// 動画があるときはカウントダウンを小さくして、動画に場所を譲る。
    private var hasVideo: Bool { video != nil && playbackState != nil }

    /// 動画の幅の上限。
    ///
    /// 実際の大きさは、この上限と「縦に余っている高さ」の小さいほうで決まる（16:9 固定のため）。
    /// 画面いっぱいには広げない。全画面の動画はうるさく、休憩が休憩でなくなる。
    private static let videoMaxWidth: CGFloat = 1600

    var body: some View {
        VStack(spacing: hasVideo ? 20 : 32) {
            Spacer(minLength: hasVideo ? 24 : 0)

            Text("腰を守るためにストレッチしよう🏋️‍♀️")
                .font(.system(size: hasVideo ? 24 : 32, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            Text(session.countdownText)
                .font(.system(size: hasVideo ? 64 : 140, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            if let video, let playbackState {
                // 前置きと動画は同じ枠に収める。差し替わるときに他の要素が動かないように。
                Group {
                    if session.videoLeadInRemaining > 0 {
                        VideoLeadInView(remaining: session.videoLeadInRemaining)
                    } else {
                        BreakVideoView(video: video, state: playbackState)
                    }
                }
                // 16:9 を明示しておくと、幅の上限と残りの高さのうち小さいほうに収まる。
                // 幅だけを指定すると、超ワイドな画面では縦がはみ出し、
                // 縦長の画面では横に余白が余る。
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: Self.videoMaxWidth, maxHeight: .infinity)
                .padding(.horizontal, 40)
                if let title = video.title.isEmpty ? nil : video.title {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.35))
                }
            } else {
                Spacer()
            }

            if session.phase == .choosingSkipReason {
                SkipReasonPicker(session: session)
            } else {
                ActionButtons(session: session)
            }

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 動画が始まる前の 3 → 2 → 1。
///
/// 数字ごとに `id` を変えて別のビュー扱いにすることで、切り替わりに transition がかかる。
private struct VideoLeadInView: View {
    let remaining: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))

            Text("\(remaining)")
                .font(.system(size: 120, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
                .id(remaining)
                .transition(.opacity.combined(with: .scale(scale: 1.25)))
        }
        .animation(.easeOut(duration: 0.3), value: remaining)
    }
}

private struct ActionButtons: View {
    @ObservedObject var session: BreakSession

    var body: some View {
        HStack(spacing: 20) {
            Button {
                session.markDone()
            } label: {
                Text("腰を守った✌️")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 24)
                    .frame(minWidth: 180, minHeight: 52)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.16))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // スキップは表示から数秒間押せない。
            // 反射でスキップを押す癖がつくのを防ぐための摩擦。
            Button {
                session.requestSkip()
            } label: {
                Text(session.canSkip ? "腰より仕事💀" : "腰より仕事💀　\(session.skipUnlockRemaining)")
                    .font(.system(size: 18, weight: .medium))
                    .monospacedDigit()
                    .padding(.horizontal, 24)
                    .frame(minWidth: 180, minHeight: 52)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(session.canSkip ? 0.08 : 0.03))
            .foregroundStyle(.white.opacity(session.canSkip ? 0.7 : 0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(!session.canSkip)
        }
    }
}

private struct SkipReasonPicker: View {
    @ObservedObject var session: BreakSession

    var body: some View {
        VStack(spacing: 18) {
            Text("なぜ腰より仕事を…？🥺")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 14) {
                ForEach(SkipReason.allCases) { reason in
                    Button {
                        session.confirmSkip(reason: reason)
                    } label: {
                        Text(reason.displayName)
                            .font(.system(size: 16))
                            .padding(.horizontal, 20)
                            .frame(minWidth: 150, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                    .background(Color.white.opacity(0.12))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            HStack(spacing: 24) {
                Button("理由を選ばずスキップ") { session.confirmSkip(reason: nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.45))

                Button("やっぱり腰を守る🏋️‍♀️") { session.cancelSkip() }
                    .buttonStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }
}

/// サブディスプレイ側。暗転とカウントダウンだけ。
private struct SecondaryOverlayView: View {
    @ObservedObject var session: BreakSession

    var body: some View {
        VStack(spacing: 20) {
            Text("腰を守っていて偉い👏")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text(session.countdownText)
                .font(.system(size: 96, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}
