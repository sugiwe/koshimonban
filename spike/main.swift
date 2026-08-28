// Koshimonban スパイク検証
//
// 目的: 本実装に入る前に、以下の2点が macOS 15 で本当に成立するかだけを確かめる。
//   1. 他アプリのネイティブフルスクリーンの「上」にオーバーレイが出るか
//   2. その時キーボードフォーカスを奪えるか（下のアプリにタイプが通ってしまわないか）
//
// 使い方:
//   ./build.sh
//   ./build/KoshimonbanSpike.app/Contents/MacOS/KoshimonbanSpike --mode 1 --delay 8
//
// --mode で collectionBehavior の組み合わせを切り替えて比較する。

import Cocoa

// MARK: - 引数

private let args = CommandLine.arguments

private func argValue(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

private let mode = Int(argValue("--mode") ?? "1") ?? 1
private let delay = Double(argValue("--delay") ?? "8") ?? 8
private let levelOverride = argValue("--level").flatMap { Int($0) }
private let duration = Double(argValue("--duration") ?? "30") ?? 30

private func behavior(for mode: Int) -> (NSWindow.CollectionBehavior, String) {
    switch mode {
    case 1:
        return ([.canJoinAllSpaces, .fullScreenAuxiliary],
                "canJoinAllSpaces + fullScreenAuxiliary  (仕様書の案)")
    case 2:
        return ([.canJoinAllSpaces],
                "canJoinAllSpaces のみ")
    case 3:
        return ([.fullScreenAuxiliary],
                "fullScreenAuxiliary のみ")
    case 4:
        return ([.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle],
                "canJoinAllSpaces + stationary + fullScreenAuxiliary + ignoresCycle")
    default:
        return ([.canJoinAllSpaces, .fullScreenAuxiliary], "既定")
    }
}

// MARK: - オーバーレイウィンドウ
//
// borderless なウィンドウは既定で key window になれないので、明示的に上書きする。
// ここが false のままだと「画面は覆えているのにタイプは下のアプリに通る」状態になる。

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - アプリ本体

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var windows: [OverlayWindow] = []
    private var keyMonitor: Any?
    private var pollTimer: Timer?
    private var countdownTimer: Timer?
    private var remaining: Double = 0

    private var countdownLabel: NSTextField!
    private var keyStatusLabel: NSTextField!
    private var typedLabel: NSTextField!
    private var typedBuffer = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // Dock に出さない

        let (_, label) = behavior(for: mode)
        print("""

        ────────────────────────────────────────────────────────
         Koshimonban スパイク検証
        ────────────────────────────────────────────────────────
         mode        : \(mode)  \(label)
         window level: \(levelOverride.map(String.init) ?? "CGShieldingWindowLevel() = \(Int(CGShieldingWindowLevel()))")
         画面数       : \(NSScreen.screens.count)

         \(Int(delay)) 秒後にオーバーレイを出します。
         今すぐ別アプリをフルスクリーンにして待ってください。
        ────────────────────────────────────────────────────────

        """)

        Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.showOverlay()
        }
    }

    // MARK: オーバーレイ表示

    private func showOverlay() {
        let (collectionBehavior, label) = behavior(for: mode)
        let level = NSWindow.Level(rawValue: levelOverride ?? Int(CGShieldingWindowLevel()))

        for (index, screen) in NSScreen.screens.enumerated() {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = level
            window.collectionBehavior = collectionBehavior
            window.isOpaque = true
            window.backgroundColor = NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.10, alpha: 1.0)
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.setFrame(screen.frame, display: true)

            let isMain = (index == 0)
            window.contentView = isMain
                ? makeMainContent(modeLabel: label, screenCount: NSScreen.screens.count)
                : makeSubContent(index: index)

            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }

        // フォーカス奪取。macOS 14 で activate(ignoringOtherApps:) は deprecated なので
        // 新 API を使い、加えて明示的に key window を指定する。
        NSApp.activate()
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        windows.first?.makeKey()

        startKeyMonitor()
        startPolling()
        startCountdown()
    }

    // MARK: メイン画面の中身

    private func makeMainContent(modeLabel: String, screenCount: Int) -> NSView {
        let root = NSView()

        let title = makeLabel("オーバーレイ検証中", size: 34, weight: .bold, color: .white)
        let modeText = makeLabel("mode \(mode): \(modeLabel)", size: 13, weight: .regular,
                                 color: NSColor.white.withAlphaComponent(0.5))
        let screenText = makeLabel("検出した画面: \(screenCount) 枚", size: 13, weight: .regular,
                                   color: NSColor.white.withAlphaComponent(0.5))

        countdownLabel = makeLabel("--", size: 96, weight: .thin, color: .white)

        let divider = NSBox()
        divider.boxType = .separator

        let instruction = makeLabel(
            "確認手順\n"
            + "1. この画面がフルスクリーンのアプリの上に出ているか\n"
            + "2. 外部ディスプレイ側も覆われているか\n"
            + "3. 今すぐ適当にキーを叩いてください。下の欄に文字が出れば入力を奪えています",
            size: 14, weight: .regular, color: NSColor.white.withAlphaComponent(0.75))

        keyStatusLabel = makeLabel("isKeyWindow: ?", size: 16, weight: .semibold, color: .systemYellow)
        typedLabel = makeLabel("（まだ何も入力されていません）", size: 20, weight: .medium, color: .systemGreen)

        let closeButton = NSButton(title: "閉じる", target: self, action: #selector(closeOverlay))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = ""   // Esc / Return で閉じないこと自体も確認したい

        let stack = NSStackView(views: [
            title, modeText, screenText, countdownLabel, divider,
            instruction, keyStatusLabel, typedLabel, closeButton
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 520),
        ])
        return root
    }

    // MARK: サブ画面の中身

    private func makeSubContent(index: Int) -> NSView {
        let root = NSView()
        let label = makeLabel("サブ画面 \(index) も覆えています", size: 28, weight: .medium,
                              color: NSColor.white.withAlphaComponent(0.8))
        label.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])
        return root
    }

    private func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = .center
        field.maximumNumberOfLines = 0
        return field
    }

    // MARK: 入力の監視

    private func startKeyMonitor() {
        // ローカルモニタはアプリがアクティブな時しか発火しない。
        // つまり「叩いても何も出ない」= 入力を奪えていない、という判定になる。
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            let chars = event.charactersIgnoringModifiers ?? ""
            self.typedBuffer = String((self.typedBuffer + chars).suffix(40))
            self.typedLabel.stringValue = "入力を受け取っています → \(self.typedBuffer)"
            return nil   // 下に流さない
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let window = self.windows.first else { return }
            let isKey = window.isKeyWindow
            let isActive = NSApp.isActive
            self.keyStatusLabel.stringValue = "isKeyWindow: \(isKey ? "YES" : "NO")   /   NSApp.isActive: \(isActive ? "YES" : "NO")"
            self.keyStatusLabel.textColor = (isKey && isActive) ? .systemGreen : .systemRed
        }
    }

    private func startCountdown() {
        remaining = duration
        updateCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remaining -= 1
            self.updateCountdown()
            if self.remaining <= 0 { self.closeOverlay() }
        }
    }

    private func updateCountdown() {
        let seconds = max(0, Int(remaining))
        countdownLabel.stringValue = String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    @objc private func closeOverlay() {
        countdownTimer?.invalidate()
        pollTimer?.invalidate()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        print("オーバーレイを閉じました。終了します。\n")
        NSApp.terminate(nil)
    }
}

// MARK: - 起動

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
