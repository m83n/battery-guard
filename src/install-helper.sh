#!/bin/bash
# Runs as root, started by BatteryGuard.app via "do shell script ... with administrator privileges".
# Usage: install-helper.sh install|uninstall RESOURCES_DIR USER_NAME
set -e

ACTION=$1
RES=$2
USER_NAME=$3

DIR=/usr/local/battery-guard
DAEMON=/Library/LaunchDaemons/local.batteryguard.daemon.plist
AGENT=/Library/LaunchAgents/local.batteryguard.menu.plist
# Earlier manual install (install.sh), replaced by this one.
OLD_DAEMON=/Library/LaunchDaemons/com.local.battery-guard.plist
OLD_AGENT=/Library/LaunchAgents/com.local.battery-guard-menu.plist

[ "$(id -u)" = 0 ] || { echo "must run as root" >&2; exit 1; }
USER_ID=$(id -u "$USER_NAME") || { echo "unknown user" >&2; exit 1; }
GUI=gui/$USER_ID

stop_all() {
    for p in "$AGENT" "$OLD_AGENT"; do launchctl bootout "$GUI" "$p" 2>/dev/null || true; done
    for p in "$DAEMON" "$OLD_DAEMON"; do launchctl bootout system "$p" 2>/dev/null || true; done
    rm -f "$OLD_DAEMON" "$OLD_AGENT" "$DIR/BatteryGuardMenu"
}

if [ "$ACTION" = uninstall ]; then
    stop_all
    [ -x "$DIR/smcctl" ] && "$DIR/smcctl" BCLM 64 || true
    rm -rf "$DIR" "$DAEMON" "$AGENT" /var/run/battery-guard.hot
    exit 0
fi

[ "$ACTION" = install ] || { echo "unknown action" >&2; exit 1; }
for f in smcctl battery-guard.sh version; do
    [ -f "$RES/$f" ] || { echo "missing $f" >&2; exit 1; }
done

stop_all
mkdir -p "$DIR"
cp "$RES/smcctl" "$RES/battery-guard.sh" "$RES/version" "$DIR/"
[ -f "$DIR/thresholds" ] || printf 'LIMIT=80\nHOT=40\nCOOL=35\n' > "$DIR/thresholds"
chown -R root:wheel "$DIR"
chmod 755 "$DIR" "$DIR/smcctl" "$DIR/battery-guard.sh"
chmod 644 "$DIR/version"
# Thresholds are edited from the menu bar app, so the user owns this one file.
chown "$USER_NAME" "$DIR/thresholds"
chmod 644 "$DIR/thresholds"

cat > "$DAEMON" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>local.batteryguard.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/battery-guard/battery-guard.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Starts the app at login by bundle id, so it works wherever the app is placed.
cat > "$AGENT" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>local.batteryguard.menu</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>-b</string>
        <string>local.batteryguard</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
</dict>
</plist>
EOF
chown root:wheel "$DAEMON" "$AGENT"
chmod 644 "$DAEMON" "$AGENT"

launchctl bootstrap system "$DAEMON"
# Agent is registered for next logins; the app is already running now, so it is not started here.
launchctl enable "$GUI/local.batteryguard.menu" 2>/dev/null || true
