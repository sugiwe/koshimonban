import Foundation
import AppKit

/// 画面ロックとスリープの検知。
///
/// ロック判定は `DistributedNotificationCenter` の通知を主に使い、
/// `CGSessionCopyCurrentDictionary` を併用して冗長化する。
/// 通知は起動前に起きた状態変化を拾えず、辞書は環境によって値が入らないことがあるため、
/// 片方だけに頼らない。
@MainActor
final class ScreenStateMonitor {

    /// 画面ロック / ロック解除 / スリープ復帰のいずれかが起きたときに呼ばれる。
    var onResume: ((String) -> Void)?
    var onSuspend: ((String) -> Void)?

    /// どの通知センターに登録したトークンかを対で持つ。
    /// 混ぜて持つと、解除時にどちらのセンターへ渡すべきか分からなくなる。
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    /// 通知で追跡しているロック状態。辞書が使えない環境ではこちらが正になる。
    private var lockedByNotification = false

    func start() {
        let distributed = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter

        observe(distributed, named: .init("com.apple.screenIsLocked")) { [weak self] in
            self?.lockedByNotification = true
            self?.onSuspend?("画面がロックされました")
        }

        observe(distributed, named: .init("com.apple.screenIsUnlocked")) { [weak self] in
            self?.lockedByNotification = false
            self?.onResume?("画面のロックが解除されました")
        }

        observe(workspace, named: NSWorkspace.willSleepNotification) { [weak self] in
            self?.onSuspend?("スリープに入ります")
        }

        observe(workspace, named: NSWorkspace.didWakeNotification) { [weak self] in
            self?.onResume?("スリープから復帰しました")
        }

        // 画面ロックを伴わない離席（ユーザー切り替え）も拾っておく
        observe(workspace, named: NSWorkspace.sessionDidResignActiveNotification) { [weak self] in
            self?.onSuspend?("セッションが非アクティブになりました")
        }

        observe(workspace, named: NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] in
            self?.onResume?("セッションがアクティブになりました")
        }
    }

    func stop() {
        for entry in observers {
            entry.center.removeObserver(entry.token)
        }
        observers.removeAll()
    }

    /// 通知の購読を登録し、解除に必要な情報を控える。
    /// `queue: .main` で登録しているので、ハンドラは必ずメインスレッドで呼ばれる。
    private func observe(_ center: NotificationCenter, named name: Notification.Name,
                         handler: @escaping () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        observers.append((center, token))
    }

    /// いま画面がロックされているか。
    var isScreenLocked: Bool {
        if let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] {
            if let locked = dictionary["CGSSessionScreenIsLocked"] as? Bool { return locked }
            if let locked = dictionary["CGSSessionScreenIsLocked"] as? Int { return locked != 0 }
            // 辞書は取れたがロックのキーが無い = ロックされていない
            if dictionary["kCGSSessionOnConsoleKey"] != nil || dictionary["kCGSSessionUserNameKey"] != nil {
                return lockedByNotification
            }
        }
        return lockedByNotification
    }

    /// このセッションが実際に画面を握っているか（ユーザー切り替え中は false）。
    var isSessionOnConsole: Bool {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] else { return true }
        if let onConsole = dictionary["kCGSSessionOnConsoleKey"] as? Bool { return onConsole }
        if let onConsole = dictionary["kCGSSessionOnConsoleKey"] as? Int { return onConsole != 0 }
        return true
    }
}
