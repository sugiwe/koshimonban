import SwiftUI

struct OverlayRootView: View {
    @ObservedObject var session: BreakSession
    let isPrimary: Bool

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.06, blue: 0.10).ignoresSafeArea()
            if isPrimary {
                PrimaryOverlayView(session: session)
            } else {
                SecondaryOverlayView(session: session)
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// メインディスプレイ側。カウントダウンとボタンを出す。
private struct PrimaryOverlayView: View {
    @ObservedObject var session: BreakSession

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("立ち上がってストレッチ")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            Text(session.countdownText)
                .font(.system(size: 140, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            // Phase 2 でここに動画が入る。
            Spacer()

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

private struct ActionButtons: View {
    @ObservedObject var session: BreakSession

    var body: some View {
        HStack(spacing: 20) {
            Button {
                session.markDone()
            } label: {
                Text("終わった")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 180, height: 52)
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
                Text(session.canSkip ? "スキップ" : "スキップ　\(session.skipUnlockRemaining)")
                    .font(.system(size: 18, weight: .medium))
                    .monospacedDigit()
                    .frame(width: 180, height: 52)
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
            Text("なぜスキップしますか")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 14) {
                ForEach(SkipReason.allCases) { reason in
                    Button {
                        session.confirmSkip(reason: reason)
                    } label: {
                        Text(reason.displayName)
                            .font(.system(size: 16))
                            .frame(width: 150, height: 48)
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

                Button("やっぱり休憩する") { session.cancelSkip() }
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
            Text("休憩中")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text(session.countdownText)
                .font(.system(size: 96, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}
