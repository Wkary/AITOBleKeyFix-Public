#!/sbin/sh
# AITO Ble Key Fix 0.0.1 - 安装脚本

if type ui_print >/dev/null 2>&1; then
    say() { ui_print "$1"; }
else
    say() { echo "$1"; }
fi

MODDIR=${MODPATH:-${0%/*}}
VER=0.0.1
if [ -f "$MODDIR/module.prop" ]; then
    VER=$(grep '^version=' "$MODDIR/module.prop" | cut -d= -f2)
fi

for f in service.sh sysapp.sh customize.sh; do
    [ -f "$MODDIR/$f" ] && chmod 755 "$MODDIR/$f" 2>/dev/null
done

SYSAPP=1
if [ -f "$MODDIR/config" ]; then
    _v=$(grep -m1 '^SYSAPP=' "$MODDIR/config" 2>/dev/null | cut -d= -f2- | tr -d '\r" ')
    case "$_v" in
        0|1) SYSAPP=$_v ;;
    esac
fi

say "==================================="
say " AITO Ble Key Fix $VER"
say "==================================="
say ""
say " 开机自动，无需任何点击:"
say "  - BLE 后台扫描切到低延迟模式"
say "  - low_latency 间隔/窗口 = 100/100ms"
say "  - AITO 加入 Doze 白名单，待机桶设为 active"
if [ "$SYSAPP" = "1" ]; then
    say "  - 自动同步已安装的 AITO 到 system/app"
else
    say "  - system/app 同步已关闭（config: SYSAPP=0）"
fi
say ""
say " 本版本无 WebUI，刷入后重启一次即可。"
say " 恢复用户应用: 把 config 的 SYSAPP 改成 0，再重启。"
say " 注意: BLE 扫描参数是全局的，会略增待机耗电。"
say "==================================="

if [ "$SYSAPP" = "1" ]; then
    say ""
    say " 正在预置系统应用副本（约 600MB，请稍等）..."
    PATH=/system/bin:/system/xbin:$PATH
    MODDIR="$MODDIR" LOG=/data/adb/aitoblekeyfix.install.log sh "$MODDIR/sysapp.sh" auto
    _rc=$?
    if [ "$_rc" = "0" ]; then
        say " 系统应用副本已就绪，重启后生效。"
    else
        say " 本次未能预置（rc=$_rc），首次开机会自动重试。"
        say " 若开机日志提示已复制，请再重启一次让系统识别。"
    fi
fi
