# 开关栏 QuickSwitch

一个轻量、开源的 macOS 菜单栏开关工具，点一下就能切换常用系统设置。

## 功能

**开关**（打勾即开启，每次打开菜单都会读取系统实时状态）

- 静音
- 隐藏桌面文件
- 夜览
- 台前调度
- 深色模式
- 防止休眠（退出后自动恢复）
- 自动隐藏程序坞
- 显示隐藏文件

**操作**

- 屏幕清洁：所有屏幕全黑并屏蔽键盘、鼠标，方便擦屏幕和键盘。按住 Esc 2 秒退出，或 2 分钟后自动退出
- 退出投屏：取消显示器镜像（AirPlay 连接不会断开，电视会变成扩展屏）

**其他**

- 开机启动

> 夜览使用了系统私有框架 CoreBrightness，未来 macOS 版本可能失效。

## 安装

需要 macOS 13 及以上，以及 Xcode 命令行工具（`xcode-select --install`）。

```bash
git clone https://github.com/prompt2app/QuickSwitch.git
cd QuickSwitch
./build.sh
```

`build.sh` 会编译、签名（ad-hoc），安装到 `/Applications/QuickSwitch.app` 并启动。

应用图标由 `icon/make_icon.swift` 用代码绘制，修改后重新生成 `icon/AppIcon.icns` 即可。

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
