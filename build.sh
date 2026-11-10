#!/bin/zsh
# 编译并安装「开关栏」到 /Applications
set -e
cd "$(dirname "$0")"

APP="build/开关栏.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 main.swift -o "$APP/Contents/MacOS/QuickSwitch"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

pkill -x QuickSwitch 2>/dev/null || true
rm -rf "/Applications/开关栏.app"
cp -R "$APP" /Applications/
open "/Applications/开关栏.app"
echo "已安装并启动：/Applications/开关栏.app"
