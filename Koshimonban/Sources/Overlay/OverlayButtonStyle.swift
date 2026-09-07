import SwiftUI

/// オーバーレイのボタンの見た目と当たり判定。
///
/// **背景をボタンの外側に付けてはいけない。**
/// `.buttonStyle(.plain)` の外側に `.background()` を重ねると、色の付いた範囲と
/// クリックできる範囲がずれて、文字の上しか反応しなくなる。
/// 押しにくさは摩擦ではなくただの不便なので、見た目と当たり判定は必ず一致させる。
///
/// スキップの5秒ロックのような意図した摩擦とは別の話。
struct OverlayButtonStyle: ButtonStyle {

    enum Emphasis {
        /// 「腰を守った✌️」。一番押してほしいもの
        case primary
        /// 「腰より仕事💀」。押せるが目立たせない
        case secondary
        /// スキップ理由の3択
        case choice
        /// 「理由を選ばずスキップ」のような、小さく添える操作
        case quiet
    }

    let emphasis: Emphasis

    func makeBody(configuration: Configuration) -> some View {
        HoverableLabel(configuration: configuration, emphasis: emphasis)
    }

    /// ホバーの状態を持つために、ButtonStyle の中でビューを1枚挟む。
    /// ButtonStyle 自体は状態を持てないため。
    private struct HoverableLabel: View {
        let configuration: Configuration
        let emphasis: Emphasis

        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, metrics.horizontalPadding)
                .frame(minWidth: metrics.minWidth, minHeight: metrics.minHeight)
                .foregroundStyle(.white.opacity(foregroundOpacity))
                .background(Color.white.opacity(backgroundOpacity))
                .clipShape(RoundedRectangle(cornerRadius: metrics.cornerRadius))
                // 見えている形をそのまま当たり判定にする
                .contentShape(RoundedRectangle(cornerRadius: metrics.cornerRadius))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .onHover { hovering in
                    // 押せないボタンにホバーの反応を出すと、押せるように見えてしまう
                    isHovering = isEnabled && hovering
                }
        }

        private var metrics: Metrics {
            switch emphasis {
            case .primary, .secondary:
                Metrics(minWidth: 180, minHeight: 52, horizontalPadding: 24, cornerRadius: 12)
            case .choice:
                Metrics(minWidth: 150, minHeight: 48, horizontalPadding: 20, cornerRadius: 10)
            case .quiet:
                // 文字だけだと的が小さすぎるので、見えない余白で的を広げる
                Metrics(minWidth: nil, minHeight: 34, horizontalPadding: 14, cornerRadius: 8)
            }
        }

        private var backgroundOpacity: Double {
            guard isEnabled else { return 0.03 }
            return switch emphasis {
            case .primary:   isHovering ? 0.28 : 0.16
            case .secondary: isHovering ? 0.16 : 0.08
            case .choice:    isHovering ? 0.22 : 0.12
            case .quiet:     isHovering ? 0.10 : 0.0
            }
        }

        private var foregroundOpacity: Double {
            guard isEnabled else { return 0.3 }
            return switch emphasis {
            case .primary:   1.0
            case .secondary: isHovering ? 0.9 : 0.7
            case .choice:    1.0
            case .quiet:     isHovering ? 0.75 : 0.45
            }
        }
    }

    private struct Metrics {
        var minWidth: CGFloat?
        var minHeight: CGFloat
        var horizontalPadding: CGFloat
        var cornerRadius: CGFloat
    }
}

extension ButtonStyle where Self == OverlayButtonStyle {
    static func overlay(_ emphasis: OverlayButtonStyle.Emphasis) -> OverlayButtonStyle {
        OverlayButtonStyle(emphasis: emphasis)
    }
}
