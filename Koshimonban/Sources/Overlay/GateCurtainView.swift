import SwiftUI

/// 左右から中央に向かって閉じる暗幕。
///
/// アプリ名のとおり「門が閉まる」動き。単なるフェードより、
/// 作業を遮断されたことが体感として伝わる。
struct GateCurtainView: View {
    let isClosed: Bool

    static let color = Color(red: 0.05, green: 0.06, blue: 0.10)

    var body: some View {
        GeometryReader { geometry in
            // 左右の板をそれぞれ画面幅の半分まで伸ばす。
            // ぴったり半分だと端数の丸めで中央に髪の毛のような隙間が出るので、
            // 1pt だけ多く伸ばして重ねる。同じ色なので重なりは見えない。
            let half = (geometry.size.width / 2).rounded(.up) + 1

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Self.color)
                    .frame(width: isClosed ? half : 0)
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Self.color)
                    .frame(width: isClosed ? half : 0)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
}
