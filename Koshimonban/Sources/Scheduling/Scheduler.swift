import Foundation
import AppKit
import Combine

/// 発動の判定を受け持つ。
///
/// **発動時刻ぴったりに Timer を1本仕掛ける方式は採らない。**
/// スリープ・時刻変更・設定変更で簡単に壊れるため、
/// 30秒ごとに起きて「いま発動すべきか」を毎回判定し直す。
@MainActor
final class Scheduler: ObservableObject {

    static let shared = Scheduler()

    /// 判定ループの周期
    static let tickInterval: TimeInterval = 30
    /// スリープ復帰・ロック解除の直後に置く猶予。復帰した瞬間に画面を奪わないため。
    static let resumeGraceSeconds: TimeInterval = 30

    // MARK: 外部との接続点

    /// オーバーレイを出す。Phase 1b で差し込む。
    var onFire: ((ScheduleGrid.Slot, Date) -> Void)?
    /// オーバーレイが表示中か。二重発動を抑止するために参照する。
    var isOverlayVisible: () -> Bool = { false }
    /// 発動しなかった回も含め、結果が確定したときに呼ばれる。
    var onResult: ((ScheduleGrid.Slot, BreakResult, Date) -> Void)?
    /// 発動の予告。1つの予定につき1回だけ呼ばれる。
    var onPreNotify: ((ScheduleGrid.Slot, Int) -> Void)?
    /// 予告を引っ込める（発動した、一時停止した、など）
    var onCancelPreNotify: (() -> Void)?

    // MARK: 観測できる状態

    @Published private(set) var events: [Event] = []
    @Published private(set) var isRunning = false
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var statusLine = "停止中"
    @Published private(set) var nextSlotLine = "—"
    @Published private(set) var todaySlotCount = 0

    struct Event: Identifiable {
        enum Kind { case info, fire, warning, resolved }
        let id = UUID()
        let at: Date
        let kind: Kind
        let message: String
    }

    // MARK: 内部状態

    private var timer: Timer?
    private var graceTimer: Timer?
    private let screenState = ScreenStateMonitor()

    /// 今日すでに決着がついた発動予定（0:00 からの経過秒）
    private var resolvedSlots: Set<Int> = []
    /// すでに予告を出した予定
    private var preNotifiedSlots: Set<Int> = []
    private var resolvedDay: Date = .distantPast
    /// この時刻までは発動しない（復帰直後の猶予）
    private var graceUntil: Date?

    private var settings: AppSettings { SettingsStore.shared.settings }

    private var calendar: Calendar { Calendar.current }

    // MARK: 開始 / 停止

    func start() {
        guard !isRunning else { return }
        isRunning = true

        screenState.onSuspend = { [weak self] reason in
            self?.log(.info, "中断: \(reason)")
        }
        screenState.onResume = { [weak self] reason in
            guard let self else { return }
            self.log(.info, "再開: \(reason)（\(Int(Self.resumeGraceSeconds))秒後に判定します）")
            self.beginGrace()
        }
        screenState.start()

        // 起動直後にいきなり画面を奪わないよう、ここでも猶予を置く。
        beginGrace()

        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 2
        // メニューを開いている間もループを止めないため common モードに入れる
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        log(.info, "スケジューラを開始しました")
        tick()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        graceTimer?.invalidate(); graceTimer = nil
        screenState.stop()
        isRunning = false
        statusLine = "停止中"
    }

    // MARK: 一時停止（逃げ道）

    func pause(for interval: TimeInterval) {
        onCancelPreNotify?()
        pausedUntil = Date().addingTimeInterval(interval)
        log(.info, "一時停止しました（\(formatted(pausedUntil!)) まで）")
        tick()
    }

    func pauseForRestOfDay() {
        onCancelPreNotify?()
        let endOfDay = calendar.startOfDay(for: Date()).addingTimeInterval(TimeInterval(ScheduleGrid.secondsPerDay))
        pausedUntil = endOfDay
        log(.info, "今日はもう発動しません")
        tick()
    }

    func resumeFromPause() {
        pausedUntil = nil
        log(.info, "一時停止を解除しました")
        tick()
    }

    var isPaused: Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > Date()
    }

    // MARK: 手動発動

    /// メニューの「今すぐ発動」。作業時間帯もグリッドも一時停止も無視して出す。
    func fireNow() {
        let now = Date()
        let nowSeconds = ScheduleGrid.secondsFromMidnight(for: now, calendar: calendar)
        let slot = ScheduleGrid.Slot(at: nowSeconds, blockStart: 0, blockEnd: ScheduleGrid.secondsPerDay)
        guard !isOverlayVisible() else {
            log(.warning, "すでにオーバーレイが出ているため、手動発動は無視しました")
            return
        }
        log(.fire, "手動で発動しました")
        onFire?(slot, now)
    }

    // MARK: 判定ループ本体

    func tick() {
        let now = Date()
        rolloverIfNeeded(now)
        updateStatus(now)

        guard isRunning else { return }

        if let graceUntil, graceUntil > now {
            return
        }

        let slots = ScheduleGrid.slots(settings: settings, date: now, calendar: calendar)
        let nowSeconds = ScheduleGrid.secondsFromMidnight(for: now, calendar: calendar)

        evaluatePreNotify(slots: slots, nowSeconds: nowSeconds)

        let due = slots.filter { $0.at <= nowSeconds && !resolvedSlots.contains($0.at) }
        guard let latest = due.last else { return }

        // 複数たまっている場合、古いものは取りこぼしとして確定させる。
        // まとめて何回も発動させても意味がないため、追いつくのは直近の1回だけ。
        for stale in due.dropLast() {
            resolve(stale, as: .missed, at: now,
                    note: "発動時刻 \(display(stale.at)) を過ぎたまま次の予定時刻になりました")
        }

        if isPaused {
            resolve(latest, as: .paused, at: now, note: "一時停止中でした")
            return
        }

        if isOverlayVisible() {
            // 二重に出さない。決着はオーバーレイ側でつく。
            return
        }

        if screenState.isScreenLocked || !screenState.isSessionOnConsole {
            // ロック中は発動しない。ただし作業時間帯が終わっていれば、もう追いつけないので確定させる。
            if !ScheduleGrid.canFire(slot: latest, atSeconds: nowSeconds, breakSeconds: settings.breakSeconds) {
                resolve(latest, as: .missed, at: now, note: "画面がロックされたまま作業時間帯が終わりました")
            }
            return
        }

        guard ScheduleGrid.canFire(slot: latest, atSeconds: nowSeconds, breakSeconds: settings.breakSeconds) else {
            resolve(latest, as: .missed, at: now, note: "追いつく前に作業時間帯が終わりました")
            return
        }

        resolvedSlots.insert(latest.at)
        onCancelPreNotify?()
        let lateBy = nowSeconds - latest.at
        if lateBy >= Int(Self.tickInterval) {
            log(.fire, "発動（予定 \(display(latest.at)) / \(lateBy)秒遅れで追いつき）")
        } else {
            log(.fire, "発動（予定 \(display(latest.at))）")
        }
        onFire?(latest, now)
    }

    // MARK: 補助

    /// 次の発動が近づいていれば予告を出す。1つの予定につき1回だけ。
    private func evaluatePreNotify(slots: [ScheduleGrid.Slot], nowSeconds: Int) {
        let leadSeconds = settings.effectivePreNotifySeconds
        guard leadSeconds > 0, !isPaused, !isOverlayVisible() else { return }
        guard !screenState.isScreenLocked else { return }
        guard let next = slots.first(where: { $0.at > nowSeconds }) else { return }

        let remaining = next.at - nowSeconds
        guard remaining <= leadSeconds, !preNotifiedSlots.contains(next.at) else { return }

        preNotifiedSlots.insert(next.at)
        log(.info, "予告: \(display(next.at)) の発動まであと \(remaining)秒")
        onPreNotify?(next, remaining)
    }

    private func resolve(_ slot: ScheduleGrid.Slot, as result: BreakResult, at date: Date, note: String) {
        resolvedSlots.insert(slot.at)
        log(.resolved, "\(display(slot.at)) → \(result.displayName)（\(note)）")
        onResult?(slot, result, date)
    }

    /// 日付が変わったら、その日の決着状況をリセットする。
    private func rolloverIfNeeded(_ now: Date) {
        let today = calendar.startOfDay(for: now)
        guard today != resolvedDay else { return }
        resolvedDay = today
        resolvedSlots.removeAll()
        preNotifiedSlots.removeAll()
        // 「今日はもう停止」を日をまたいで持ち越さない
        if let pausedUntil, pausedUntil <= now {
            self.pausedUntil = nil
        }
    }

    private func beginGrace() {
        let until = Date().addingTimeInterval(Self.resumeGraceSeconds)
        graceUntil = until
        graceTimer?.invalidate()
        // 猶予が明けた瞬間に判定する。次の定期 tick を待つと最大30秒余計に遅れるため。
        let timer = Timer(fire: until.addingTimeInterval(0.5), interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        graceTimer = timer
    }

    private func updateStatus(_ now: Date) {
        let slots = ScheduleGrid.slots(settings: settings, date: now, calendar: calendar)
        todaySlotCount = slots.count
        let nowSeconds = ScheduleGrid.secondsFromMidnight(for: now, calendar: calendar)

        if let next = slots.first(where: { $0.at > nowSeconds }) {
            let remaining = next.at - nowSeconds
            nextSlotLine = "\(display(next.at))（あと \(durationText(remaining))）"
        } else {
            nextSlotLine = slots.isEmpty ? "今日は発動予定なし" : "今日の発動予定は終了しました"
        }

        if !isRunning {
            statusLine = "停止中"
        } else if isPaused, let pausedUntil {
            statusLine = "一時停止中（\(formatted(pausedUntil)) まで）"
        } else if let graceUntil, graceUntil > now {
            statusLine = "復帰直後のため待機中"
        } else if screenState.isScreenLocked {
            statusLine = "画面ロック中のため待機"
        } else if isOverlayVisible() {
            statusLine = "休憩中"
        } else {
            statusLine = "稼働中"
        }
    }

    private func display(_ seconds: Int) -> String {
        settings.debugMode
            ? ScheduleGrid.preciseTimeString(fromSeconds: seconds)
            : ScheduleGrid.timeString(fromSeconds: seconds)
    }

    private func durationText(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)秒" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)分" }
        return "\(minutes / 60)時間\(minutes % 60)分"
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func log(_ kind: Event.Kind, _ message: String) {
        events.append(Event(at: Date(), kind: kind, message: message))
        if events.count > 200 { events.removeFirst(events.count - 200) }
        NSLog("[Koshimonban] \(message)")
    }

    func clearEvents() {
        events.removeAll()
    }

    /// オーバーレイ側で休憩が決着したことを受け取る。判定ログに残し、状態表示を更新する。
    func noteBreakFinished(result: BreakResult, reason: SkipReason?, shownSeconds: Int) {
        let reasonText = reason.map { "・\($0.displayName)" } ?? ""
        log(.resolved, "休憩終了: \(result.displayName)\(reasonText)（表示 \(shownSeconds)秒）")
        tick()
    }
}
