#!/bin/bash
# Runs as root every 60 s (launchd). Keeps charge limit at LIMIT %,
# stops charging while battery is hot (BCLM = gauge %), resumes when cool.

PATH=/usr/bin:/bin:/usr/sbin:/sbin
SMC=/usr/local/battery-guard/smcctl
FLAG=/var/run/battery-guard.hot
CONF=/usr/local/battery-guard/thresholds

# Config is user-writable: accept only integers within MIN..MAX, else DEFAULT.
read_val() {
    local v
    v=$(awk -F= -v k="$1" '$1==k {print $2}' "$CONF" 2>/dev/null | tr -d '[:space:]' | head -1)
    if [[ "$v" =~ ^[0-9]{1,3}$ ]] && (( 10#$v >= $2 && 10#$v <= $3 )); then
        echo $((10#$v))
    else
        echo "$4"
    fi
}
LIMIT=$(read_val LIMIT 50 100 80)
HOT=$(read_val HOT 30 60 40)
COOL=$(read_val COOL 25 59 35)
[ "$COOL" -lt "$HOT" ] || COOL=$((HOT - 5))

temp=$(ioreg -rn AppleSmartBattery | awk '/"Temperature" =/{print int($3/100)}')
pct=$(pmset -g batt | grep -Eo '[0-9]+%' | head -1 | tr -d %)
[ -z "$temp" ] || [ -z "$pct" ] && exit 0
# SMC compares BCLM with the gauge's own charge, which reads a few % lower than macOS.
soc=$(ioreg -rn AppleSmartBattery | grep -oE '"StateOfCharge"=[0-9]+' | head -1 | cut -d= -f2)
[ -n "$soc" ] || soc=$pct

if [ "$temp" -ge "$HOT" ] && [ ! -f "$FLAG" ]; then
    touch "$FLAG"
    logger -t battery-guard "battery ${temp}C, charging paused"
elif [ "$temp" -lt "$COOL" ] && [ -f "$FLAG" ]; then
    rm -f "$FLAG"
    logger -t battery-guard "battery ${temp}C, charging resumed"
fi

# Hot, or macOS already shows LIMIT: hold charge where the gauge is now.
target=$LIMIT
if [ -f "$FLAG" ] || { [ "$LIMIT" -lt 100 ] && [ "$pct" -ge "$LIMIT" ]; }; then
    [ "$soc" -lt "$LIMIT" ] && target=$soc
fi

want=$(printf '%02x' "$target")
[ "$($SMC BCLM)" = "$want" ] || $SMC BCLM "$want" || logger -t battery-guard "BCLM write failed"
