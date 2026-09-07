import SwiftUI

struct OverlayRootView: View {
    @ObservedObject var session: BreakSession
    @ObservedObject var gate: GateAnimation
    let isPrimary: Bool
    let video: VideoEntry?
    let playbackState: VideoPlaybackState?

    var body: some View {
        ZStack {
            // 門が閉じきる前でも、クリックを下のアプリに通さないための下地。
            //
            // **完全に透明（alpha 0）にしてはいけない。** macOS は透明な領域への
            // クリックを下のウィンドウへ素通しするため、門が閉じるまでの数百ミリ秒だけ
            // 作業を続けられてしまう。目に見えない濃さで敷いておけば、
            // 見た目は透けたままクリックはこちらが受け止める。
            Color.black.opacity(0.02).ignoresSafeArea()

            GateCurtainView(isClosed: gate.isClosed)

            // 全ディスプレイで同じ画面を出す。
            //
            // **動画だけはメイン1枚に限る。** 全画面で再生すると音が画面の枚数だけ
            // 重なって鳴り、YouTube も枚数ぶん読み込むことになる。
            // 動画が無い場合のレイアウトは元からあるので、サブには動画を渡さないだけでよい。
            //
            // ボタンは全画面に出す。どの画面の前にいても休憩を終われるようにするため。
            BreakContentView(session: session,
                             video: isPrimary ? video : nil,
                             playbackState: isPrimary ? playbackState : nil)
            // 中身は門が閉じきってから出す。閉じる途中で文字が見えると落ち着かない。
            .opacity(gate.showsContent ? 1 : 0)
            // opacity だけではクリックもキー入力も生きたままになる。
            // オーバーレイは0秒目からキーウィンドウなので、タイプ中に発動すると
            // 見えない「腰を守った✌️」に Space や Return が入り、休憩が即座に終わりうる。
            .allowsHitTesting(gate.showsContent)
        }
        .preferredColorScheme(.dark)
    }
}

/// 休憩中の中身。カウントダウン・動画・ボタン。
/// 動画を渡さなければ、動画なしのレイアウトになる（サブディスプレイ用）。
private struct BreakContentView: View {
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

            Text("腰を守っていて偉い👏")
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

    /// 背景に敷くアプリ名の濃さ。数字の邪魔をしない程度に留める。
    private static let wordmarkOpacity: Double = 0.10
    /// 実際の大きさは枠に合わせて縮む。ここは「縮む前の上限」なので、
    /// 枠より確実に大きい値を置いて、常に枠幅いっぱいまで広がるようにする。
    private static let wordmarkMaxFontSize: CGFloat = 800

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))

            // 枠いっぱいのアプリ名。カウントダウンの背後に薄く敷く。
            Text("腰門番")
                .font(.system(size: Self.wordmarkMaxFontSize, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.05)
                .foregroundStyle(.white.opacity(Self.wordmarkOpacity))
                .padding(.horizontal, 24)

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
            }
            .buttonStyle(.overlay(.primary))

            // スキップは表示から数秒間押せない。
            // 反射でスキップを押す癖がつくのを防ぐための摩擦。
            Button {
                session.requestSkip()
            } label: {
                // カウントダウンの数字が消えるとボタンが縮み、中央揃えの列がずれて
                // 隣の「腰を守った✌️」まで動く。最長の状態で幅を決めておく。
                //
                // 数字を直接書かず見えないラベルで幅を取るのは、文字やフォントを
                // 変えたときに数値の調整が要らないようにするため。
                ZStack {
                    Text("腰より仕事💀　00")
                        .hidden()
                    Text(session.canSkip ? "腰より仕事💀" : "腰より仕事💀　\(session.skipUnlockRemaining)")
                }
                .font(.system(size: 18, weight: .medium))
                .monospacedDigit()
            }
            .buttonStyle(.overlay(.secondary))
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
                    }
                    .buttonStyle(.overlay(.choice))
                }
            }

            HStack(spacing: 12) {
                Button {
                    session.confirmSkip(reason: nil)
                } label: {
                    Text("理由を選ばずスキップ").font(.system(size: 14))
                }
                .buttonStyle(.overlay(.quiet))

                Button {
                    session.cancelSkip()
                } label: {
                    Text("やっぱり腰を守る🏋️‍♀️").font(.system(size: 14))
                }
                .buttonStyle(.overlay(.quiet))
            }
        }
    }
}
