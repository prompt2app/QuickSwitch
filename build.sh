#!/bin/zsh
# 编译并安装 QuickSwitch到 /Applications
set -e
cd "$(dirname "$0")"

APP="build/QuickSwitch.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 main.swift -o "$APP/Contents/MacOS/QuickSwitch"
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

pkill -x QuickSwitch 2>/dev/null || true
rm -rf "/Applications/开关栏.app" "/Applications/QuickSwitch.app"
cp -R "$APP" /Applications/
open "/Applications/QuickSwitch.app"
echo "已安装并启动：/Applications/QuickSwitch.app"
