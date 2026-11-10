// 开关栏（QuickSwitch）—— 菜单栏一键开关工具
// 编译：./build.sh

import AppKit
import ServiceManagement
import CoreAudio

// MARK: - Shell 工具

@discardableResult
func sh(_ cmd: String) -> String {
    let p = Process()
    let out = Pipe()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-c", cmd]
    p.standardOutput = out
    p.standardError = Pipe()
    do { try p.run() } catch { return "" }
    p.waitUntilExit()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func osa(_ script: String) -> String {
    sh("osascript -e '\(script)'")
}

/// 读取偏好设置布尔值（直接调用 CFPreferences，不启动进程，几乎零耗时）
func readBool(_ domain: String, _ key: String, fallback: Bool) -> Bool {
    let d = domain as CFString
    CFPreferencesAppSynchronize(d)   // 读取其他进程刚写入的最新值
    guard let v = CFPreferencesCopyAppValue(key as CFString, d) else { return fallback }
    if let b = v as? Bool { return b }
    if let n = v as? NSNumber { return n.boolValue }
    if let str = v as? String { return ["1", "true", "yes"].contains(str.lowercased()) }
    return fallback
}

/// 当前是否深色模式（读全局偏好 AppleInterfaceStyle）
func isDarkMode() -> Bool {
    CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
    let v = CFPreferencesCopyAppValue("AppleInterfaceStyle" as CFString, kCFPreferencesAnyApplication)
    return (v as? String) == "Dark"
}

/// 默认输出设备是否静音（CoreAudio，不走 AppleScript）
func isOutputMuted() -> Bool {
    var device = AudioObjectID(0)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                          mScope: kAudioObjectPropertyScopeGlobal,
                                          mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device) == noErr
    else { return false }
    var muted = UInt32(0)
    size = UInt32(MemoryLayout<UInt32>.size)
    addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                      mScope: kAudioDevicePropertyScopeOutput,
                                      mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &muted) == noErr else { return false }
    return muted != 0
}

// MARK: - 夜览（调用系统私有框架 CoreBrightness）

enum NightShift {
    nonisolated(unsafe) private static let client: NSObject? = {
        dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        guard let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type else { return nil }
        return cls.init()
    }()

    static var available: Bool { client != nil }

    static func isOn() -> Bool {
        let sel = NSSelectorFromString("getBlueLightStatus:")
        guard let c = client, c.responds(to: sel) else { return false }
        typealias F = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
        let f = unsafeBitCast(c.method(for: sel), to: F.self)
        // 状态结构体：{ BOOL active; BOOL enabled; ... }，enabled 在偏移 1
        let buf = UnsafeMutableRawPointer.allocate(byteCount: 128, alignment: 8)
        defer { buf.deallocate() }
        buf.initializeMemory(as: UInt8.self, repeating: 0, count: 128)
        guard f(c, sel, buf) else { return false }
        return buf.load(fromByteOffset: 1, as: UInt8.self) != 0
    }

    static func set(_ on: Bool) {
        let sel = NSSelectorFromString("setEnabled:")
        guard let c = client, c.responds(to: sel) else { return }
        typealias F = @convention(c) (AnyObject, Selector, Bool) -> Bool
        let f = unsafeBitCast(c.method(for: sel), to: F.self)
        _ = f(c, sel, on)
    }
}

// MARK: - 镜像显示（系统公开接口 CoreGraphics）

enum Mirroring {
    static func onlineDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }

    /// 是否有显示器处于镜像状态（包括 AirPlay 投屏）
    static func isActive() -> Bool {
        onlineDisplays().contains { CGDisplayIsInMirrorSet($0) != 0 }
    }

    /// 取消所有镜像，成功返回 true
    static func stop() -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }
        for d in onlineDisplays() where CGDisplayMirrorsDisplay(d) != kCGNullDirectDisplay {
            CGConfigureDisplayMirrorOfDisplay(config, d, kCGNullDirectDisplay)
        }
        return CGCompleteDisplayConfiguration(config, .forSession) == .success
    }
}

// MARK: - 开关定义

struct Switch {
    let title: String
    let symbol: String
    let isOn: () -> Bool
    let set: (Bool) -> Void
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var caffeinate: Process?
    private var switches: [Switch] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "switch.2", accessibilityDescription: "QuickSwitch")

        switches = [
            Switch(title: "静音", symbol: "speaker.slash",
                   isOn: { isOutputMuted() },
                   set: { on in _ = osa("set volume output muted \(on)") }),
            Switch(title: "隐藏桌面文件", symbol: "eye.slash",
                   isOn: { !readBool("com.apple.finder", "CreateDesktop", fallback: true) },
                   set: { on in
                       sh("defaults write com.apple.finder CreateDesktop -bool \(!on); killall Finder")
                   }),
            Switch(title: "夜览", symbol: "sun.horizon",
                   isOn: { NightShift.isOn() },
                   set: { on in NightShift.set(on) }),
            Switch(title: "台前调度", symbol: "rectangle.leadinghalf.inset.filled",
                   isOn: { readBool("com.apple.WindowManager", "GloballyEnabled", fallback: false) },
                   set: { on in
                       // 写入设置后重启 WindowManager 让它立即生效
                       sh("defaults write com.apple.WindowManager GloballyEnabled -bool \(on); killall WindowManager")
                   }),
            Switch(title: "深色模式", symbol: "moon",
                   isOn: { isDarkMode() },
                   set: { on in
                       _ = osa("tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)")
                   }),
            Switch(title: "防止休眠", symbol: "cup.and.saucer",
                   isOn: { [weak self] in self?.caffeinate?.isRunning ?? false },
                   set: { [weak self] on in self?.setCaffeinate(on) }),
            Switch(title: "自动隐藏程序坞", symbol: "dock.rectangle",
                   isOn: { readBool("com.apple.dock", "autohide", fallback: false) },
                   set: { on in
                       sh("defaults write com.apple.dock autohide -bool \(on); killall Dock")
                   }),
            Switch(title: "显示隐藏文件", symbol: "doc.badge.ellipsis",
                   isOn: { readBool("com.apple.finder", "AppleShowAllFiles", fallback: false) },
                   set: { on in
                       sh("defaults write com.apple.finder AppleShowAllFiles -bool \(on); killall Finder")
                   }),
        ]

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        caffeinate?.terminate()
    }

    // 每次打开菜单时重新读取状态，保证勾选和系统实际一致
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        for (i, s) in switches.enumerated() {
            let item = NSMenuItem(title: s.title, action: #selector(toggle(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            item.state = s.isOn() ? .on : .off
            item.image = NSImage(systemSymbolName: s.symbol, accessibilityDescription: nil)
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let clean = NSMenuItem(title: "屏幕清洁", action: #selector(startCleaning), keyEquivalent: "")
        clean.target = self
        clean.image = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: nil)
        menu.addItem(clean)

        let mirrored = Mirroring.isActive()
        let cast = NSMenuItem(title: mirrored ? "退出投屏（取消镜像）" : "退出投屏（当前未镜像）",
                              action: mirrored ? #selector(stopMirroring) : nil, keyEquivalent: "")
        cast.target = self
        cast.isEnabled = mirrored
        cast.image = NSImage(systemSymbolName: "rectangle.on.rectangle.slash", accessibilityDescription: nil)
        menu.addItem(cast)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "开机启动", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        let quit = NSMenuItem(title: "退出 QuickSwitch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func toggle(_ sender: NSMenuItem) {
        let s = switches[sender.tag]
        s.set(sender.state != .on)
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "设置开机启动失败"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private let cleaner = ScreenCleaner()

    @objc private func startCleaning() {
        cleaner.start()
    }

    /// 退出投屏：取消所有显示器镜像。AirPlay 连接不会断开，电视会变成扩展屏
    @objc private func stopMirroring() {
        if !Mirroring.stop() {
            let alert = NSAlert()
            alert.messageText = "取消镜像失败"
            alert.informativeText = "可以在「系统设置 → 显示器」里手动断开投屏。"
            alert.runModal()
        }
    }

    private func setCaffeinate(_ on: Bool) {
        if on {
            guard caffeinate?.isRunning != true else { return }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            p.arguments = ["-di", "-w", "\(ProcessInfo.processInfo.processIdentifier)"]
            try? p.run()
            caffeinate = p
        } else {
            caffeinate?.terminate()
            caffeinate = nil
        }
    }
}

// MARK: - 屏幕清洁

/// 所有屏幕全黑，屏蔽键盘和鼠标点击，方便擦屏幕和键盘。
/// 退出方式：按住 Esc 2 秒；或 2 分钟后自动退出（防止困住）。
final class CleanWindow: NSWindow {
    var onKeyDown: ((NSEvent) -> Void)?
    var onKeyUp: ((NSEvent) -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func keyDown(with event: NSEvent) { onKeyDown?(event) }      // 吞掉按键
    override func keyUp(with event: NSEvent) { onKeyUp?(event) }
    override func performKeyEquivalent(with event: NSEvent) -> Bool { true } // 吞掉 ⌘ 组合键
}

@MainActor
final class ScreenCleaner {
    private var windows: [CleanWindow] = []
    private var escTimer: Timer?
    private var countdownTimer: Timer?
    private var hintLabels: [NSTextField] = []
    private var remaining = 120
    private let holdSeconds = 2.0
    private let maxSeconds = 120

    var isRunning: Bool { !windows.isEmpty }

    func start() {
        guard !isRunning else { return }
        remaining = maxSeconds

        for screen in NSScreen.screens {
            let w = CleanWindow(contentRect: screen.frame, styleMask: .borderless,
                                backing: .buffered, defer: false, screen: screen)
            w.level = .screenSaver
            w.backgroundColor = .black
            w.isOpaque = true
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            w.setFrame(screen.frame, display: true)
            w.onKeyDown = { [weak self] e in self?.keyDown(e) }
            w.onKeyUp = { [weak self] e in self?.keyUp(e) }

            let label = NSTextField(labelWithString: "")
            label.textColor = NSColor(white: 0.35, alpha: 1)
            label.font = .systemFont(ofSize: 16)
            label.alignment = .center
            label.frame = NSRect(x: 0, y: 40, width: screen.frame.width, height: 24)
            w.contentView?.addSubview(label)
            hintLabels.append(label)

            w.orderFrontRegardless()
            windows.append(w)
        }
        updateHint()

        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching,
                                     .disableForceQuit, .disableSessionTermination,
                                     .disableHideApplication, .disableAppleMenu]
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
        NSCursor.hide()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.remaining -= 1
                if self.remaining <= 0 { self.stop() } else { self.updateHint() }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        escTimer?.invalidate(); escTimer = nil
        countdownTimer?.invalidate(); countdownTimer = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        hintLabels.removeAll()
        NSApp.presentationOptions = []
        NSCursor.unhide()
    }

    private func updateHint() {
        let text = "屏幕清洁中 · 按住 Esc \(Int(holdSeconds)) 秒退出 · \(remaining) 秒后自动退出"
        hintLabels.forEach { $0.stringValue = text }
    }

    private func keyDown(_ e: NSEvent) {
        guard e.keyCode == 53, !e.isARepeat, escTimer == nil else { return } // 53 = Esc
        escTimer = Timer.scheduledTimer(withTimeInterval: holdSeconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
    }

    private func keyUp(_ e: NSEvent) {
        guard e.keyCode == 53 else { return }
        escTimer?.invalidate(); escTimer = nil
    }
}

// MARK: - 入口

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
