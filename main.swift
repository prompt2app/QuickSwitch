// 开关栏（QuickSwitch）—— 菜单栏一键开关工具
// 编译：./build.sh

import AppKit
import ServiceManagement

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

/// 读取 defaults 布尔值，读不到时返回 fallback
func readBool(_ domain: String, _ key: String, fallback: Bool) -> Bool {
    let v = sh("defaults read \(domain) \(key) 2>/dev/null").lowercased()
    if v.isEmpty { return fallback }
    return v == "1" || v == "true" || v == "yes"
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
        statusItem.button?.image = NSImage(systemSymbolName: "switch.2", accessibilityDescription: "开关栏")

        switches = [
            Switch(title: "隐藏桌面图标", symbol: "eye.slash",
                   isOn: { !readBool("com.apple.finder", "CreateDesktop", fallback: true) },
                   set: { on in
                       sh("defaults write com.apple.finder CreateDesktop -bool \(!on); killall Finder")
                   }),
            Switch(title: "深色模式", symbol: "moon",
                   isOn: { sh("defaults read -g AppleInterfaceStyle 2>/dev/null") == "Dark" },
                   set: { on in
                       _ = osa("tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)")
                   }),
            Switch(title: "防止休眠", symbol: "cup.and.saucer",
                   isOn: { [weak self] in self?.caffeinate?.isRunning ?? false },
                   set: { [weak self] on in self?.setCaffeinate(on) }),
            Switch(title: "静音", symbol: "speaker.slash",
                   isOn: { osa("output muted of (get volume settings)") == "true" },
                   set: { on in _ = osa("set volume output muted \(on)") }),
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

        let login = NSMenuItem(title: "开机启动", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        let quit = NSMenuItem(title: "退出开关栏", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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

// MARK: - 入口

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
