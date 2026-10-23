#!/system/bin/sh
# AITO Ble Key Fix 0.0.1 - 开机应用极速档

MODDIR=${0%/*}
CFG="$MODDIR/config"
LOG=${LOG:-/data/adb/aitoblekeyfix.log}
PATH=/system/bin:/system/xbin:$PATH
export PATH

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(ts) $*" >> "$LOG" 2>/dev/null; }

cfg_get() {
    v=""
    [ -f "$CFG" ] && v=$(grep -m1 "^$1=" "$CFG" 2>/dev/null | cut -d= -f2- | tr -d '\r" ')
    [ -n "$v" ] && echo "$v" || echo "$2"
}

for f in service.sh sysapp.sh customize.sh; do
    [ -f "$MODDIR/$f" ] && chmod 755 "$MODDIR/$f" 2>/dev/null
done

[ -f "$LOG" ] && mv -f "$LOG" "$LOG.1" 2>/dev/null
echo "=== AITO Ble Key Fix 0.0.1 boot @ $(ts) ===" > "$LOG"
chmod 640 "$LOG" 2>/dev/null

SYSAPP=$(cfg_get SYSAPP 1)
case "$SYSAPP" in
    0|1) ;;
    *) SYSAPP=1 ;;
esac

i=0
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    i=$((i+1))
    [ "$i" -ge 60 ] && break
done
log "sys.boot_completed=$(getprop sys.boot_completed) 等待 $((i*2))s"

i=0
v=""
while :; do
    v=$(settings get global airplane_mode_on 2>/dev/null)
    case "$v" in
        ''|null) ;;
        *) break ;;
    esac
    sleep 3
    i=$((i+1))
    [ "$i" -ge 30 ] && break
done
log "settings 就绪: airplane_mode_on=${v:-null}（约 $((i*3))s）"

i=0
pid=""
while :; do
    pid=$(pidof com.android.bluetooth 2>/dev/null)
    [ -n "$pid" ] && break
    sleep 3
    i=$((i+1))
    [ "$i" -ge 20 ] && break
done
log "蓝牙栈: pid=${pid:-DEAD}（约 $((i*3))s）"

settings put global ble_scan_background_mode 2 2>>"$LOG"
settings put global ble_scan_low_latency_interval_ms 100 2>>"$LOG"
settings put global ble_scan_low_latency_window_ms 100 2>>"$LOG"
settings put global ble_scan_always_enabled 1 2>>"$LOG"
log "写入: mode=$(settings get global ble_scan_background_mode) ll=$(settings get global ble_scan_low_latency_interval_ms)/$(settings get global ble_scan_low_latency_window_ms) always=$(settings get global ble_scan_always_enabled)"

for PKG in app.huawei.auto app.huawei.motor; do
    if [ -n "$(pm path "$PKG" 2>/dev/null)" ]; then
        cmd deviceidle whitelist +"$PKG" >> "$LOG" 2>&1
        am set-standby-bucket "$PKG" active >> "$LOG" 2>&1
        _wl=$(cmd deviceidle whitelist 2>/dev/null | grep -c "$PKG")
        _bucket=$(am get-standby-bucket "$PKG" 2>/dev/null)
        log "Doze 白名单=${_wl:-0} standby=${_bucket:-?}: $PKG"
    else
        log "未安装，跳过: $PKG"
    fi
done

if [ "$SYSAPP" = "1" ]; then
    log "系统应用同步开始"
    MODDIR="$MODDIR" LOG="$LOG" sh "$MODDIR/sysapp.sh" auto
    log "系统应用同步结束 rc=$?"
else
    if [ -d "$MODDIR/system/app" ]; then
        rm -rf "$MODDIR/system/app" "$MODDIR/.sysapp-stage" "$MODDIR/.sysapp-old"
        log "SYSAPP=0：已删除系统应用副本，下次重启恢复为用户应用"
    else
        rm -rf "$MODDIR/.sysapp-stage" "$MODDIR/.sysapp-old"
        log "SYSAPP=0：跳过系统应用同步"
    fi
fi

log "=== done @ $(ts) ==="
