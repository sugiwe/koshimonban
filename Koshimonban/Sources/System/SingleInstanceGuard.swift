import AppKit

/// 同じアプリが二重に起動するのを防ぐ。
///
/// LaunchAgent を登録すると launchd がもう1つ起動してしまい、
/// メニューバーにアイコンが2つ並ぶ。手で二度起動した場合も同じ。
/// 後から起動した方が黙って引き下がる。
enum SingleInstanceGuard {

    /// 自分が後発なら true を返す（呼び出し側で終了する）
    static func shouldTerminateBecauseAnotherInstanceIsRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let current = NSRunningApplication.current
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != current.processIdentifier }
        guard !others.isEmpty else { return false }

        // 先に起動していた方を残す。起動時刻が取れない場合は自分が引き下がる。
        let currentLaunch = current.launchDate ?? Date()
        return others.contains { ($0.launchDate ?? Date.distantPast) < currentLaunch }
    }
}
