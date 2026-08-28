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
    /// 引数は「作業に戻ってきた」= 猶予を置いてから発動を再開すべきか。
    var onResume: ((String) -> Void)?
    var onSuspend: ((String) -> Void)?

    private var observers: [NSObjectProtocol] = []

    /// 通知で追跡しているロック状態。辞書が使えない環境ではこちらが正になる。
    private var lockedByNotification = false

    func start() {
        let distributed = DistributedNotificationCenter.default()

        observers.append(distributed.addObserver(
            forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.lockedByNotification = true
                self?.onSuspend?("画面がロックされました")
            }
        })

        observers.append(distributed.addObserver(
            forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.lockedByNotification = false
                self?.onResume?("画面のロックが解除されました")
            }
        })

        let workspace = NSWorkspace.shared.notificationCenter

        observers.append(workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onSuspend?("スリープに入ります") }
        })

        observers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onResume?("スリープから復帰しました") }
        })

        // 画面ロックを伴わない離席（ユーザ切り替え）も拾っておく
        observers.append(workspace.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onSuspend?("セッションが非アクティブになりました") }
        })

        observers.append(workspace.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onResume?("セッションがアクティブになりました") }
        })
    }

    func stop() {
        let distributed = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter
        for observer in observers {
            distributed.removeObserver(observer)
            workspace.removeObserver(observer)
        }
        observers.removeAll()
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

    /// このセッションが実際に画面を握っているか（ユーザ切り替え中は false）。
    var isSessionOnConsole: Bool {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] else { return true }
        if let onConsole = dictionary["kCGSSessionOnConsoleKey"] as? Bool { return onConsole }
        if let onConsole = dictionary["kCGSSessionOnConsoleKey"] as? Int { return onConsole != 0 }
        return true
    }
}
