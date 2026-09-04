import SwiftUI

/// 門の開閉の進行状態。全ディスプレイのオーバーレイが同じ動きをするよう、
/// 1回の休憩につき1つを作って各画面で共有する。
@MainActor
final class GateAnimation: ObservableObject {
    /// 門が閉じきっているか。false のとき中央が開いていて下の画面が見える。
    @Published var isClosed = false
    /// 中身（カウントダウン・動画・ボタン）を出しているか。
    /// 門が閉じきってから出す。閉じる途中で文字が見えると落ち着かないため。
    @Published var showsContent = false
}
