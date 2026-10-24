#!/bin/bash
# Builds build/BatteryGuard.app and build/BatteryGuard-VERSION.zip (Intel, macOS 11+).
set -e
cd "$(dirname "$0")"

VERSION=1.0.1
# Service version = hash of the files installed as root: when any of them changes,
# installed users are asked to reinstall the service (admin password).
SERVICE_VERSION=$(cat src/battery-guard.sh src/smcctl.c src/install-helper.sh | shasum -a 256 | cut -c1-12)
APP=build/BatteryGuard.app
TARGET=x86_64-apple-macos11.0

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -target "$TARGET" -o "$APP/Contents/MacOS/BatteryGuard" src/BatteryGuard.swift
cc -O2 -target "$TARGET" -framework IOKit -framework CoreFoundation -o "$APP/Contents/Resources/smcctl" src/smcctl.c
cp src/battery-guard.sh src/install-helper.sh "$APP/Contents/Resources/"
echo "$SERVICE_VERSION" > "$APP/Contents/Resources/version"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>local.batteryguard</string>
    <key>CFBundleName</key>
    <string>BatteryGuard</string>
    <key>CFBundleExecutable</key>
    <string>BatteryGuard</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc signature: no Apple Developer ID, users confirm the first launch in System Settings.
codesign --force --sign - "$APP/Contents/Resources/smcctl"
codesign --force --sign - "$APP"
(cd build && ditto -c -k --keepParent BatteryGuard.app "BatteryGuard-$VERSION.zip")
echo "Built $APP and build/BatteryGuard-$VERSION.zip"
