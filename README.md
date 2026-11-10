# 开关栏 QuickSwitch

一个轻量、开源的 macOS 菜单栏开关工具，点一下就能切换常用系统设置。

## 功能

- 隐藏桌面图标
- 深色模式
- 防止休眠（退出后自动恢复）
- 静音
- 自动隐藏程序坞
- 显示隐藏文件
- 开机启动

每次打开菜单都会读取系统当前状态，勾选始终与系统一致。

## 安装

需要 macOS 13 及以上，以及 Xcode 命令行工具（`xcode-select --install`）。

```bash
git clone https://github.com/prompt2app/QuickSwitch.git
cd QuickSwitch
./build.sh
```

`build.sh` 会编译、签名（ad-hoc），安装到 `/Applications/开关栏.app` 并启动。

首次切换「深色模式」或「静音」时，系统会询问是否允许控制“系统事件”，点击允许即可。

## 添加新开关

所有代码都在 `main.swift`。在 `switches` 数组里加一项即可：

```swift
Switch(title: "名称", symbol: "SF Symbol 名",
       isOn: { /* 返回当前状态 */ },
       set: { on in /* 执行切换 */ })
```

## 许可证

MIT
