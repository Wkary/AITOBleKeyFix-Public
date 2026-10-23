#!/system/bin/sh
# AITO Ble Key Fix 0.0.1 - 将已安装的 AITO 同步到模块 system/app
# 只在文件变化时复制；native 库按设备 ABI 解包到 lib/<abi>/

MODDIR=${MODDIR:-${0%/*}}
LOG=${LOG:-/data/adb/aitoblekeyfix.log}
PATH=/system/bin:/system/xbin:$PATH
export PATH

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(ts) [sysapp] $*" >> "$LOG" 2>/dev/null || echo "[sysapp] $*"; }

ROOT="$MODDIR/system/app"
ABI=$(getprop ro.product.cpu.abi 2>/dev/null)
case "$ABI" in
    arm64-v8a) ABI_DIR=arm64-v8a; LIB_DIR=arm64 ;;
    armeabi-v7a|armeabi) ABI_DIR=armeabi-v7a; LIB_DIR=arm ;;
    x86_64) ABI_DIR=x86_64; LIB_DIR=x86_64 ;;
    x86) ABI_DIR=x86; LIB_DIR=x86 ;;
    *) ABI_DIR=$ABI; LIB_DIR=$ABI ;;
esac

TARGET="${1:-auto}"
if [ "$TARGET" = "auto" ]; then
    for p in app.huawei.auto app.huawei.motor; do
        if [ -n "$(pm path "$p" 2>/dev/null)" ]; then
            TARGET=$p
            break
        fi
    done
fi
if [ -z "$TARGET" ] || [ "$TARGET" = "auto" ]; then
    log "未检测到 AITO，跳过"
    exit 1
fi

SRC_LIST=$(pm path "$TARGET" 2>/dev/null | sed -n 's/^package://p')
if [ -z "$SRC_LIST" ]; then
    log "$TARGET 未安装，跳过"
    exit 1
fi

SRC_DATA=$(printf '%s\n' "$SRC_LIST" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in
        "$ROOT"/*|"$MODDIR"/*|/data/adb/*|/system/*|/product/*|/system_ext/*|/vendor/*|/odm/*|/apex/*) ;;
        *) printf '%s\n' "$p" ;;
    esac
done)

DEST="$ROOT/$TARGET"
if [ -z "$SRC_DATA" ]; then
    if [ -f "$DEST/base.apk" ]; then
        log "$TARGET 当前已由系统应用副本提供，无用户更新，跳过"
    else
        log "$TARGET 只有系统路径，未找到可复制的用户 APK，跳过"
    fi
    exit 0
fi

if ! command -v unzip >/dev/null 2>&1; then
    log "unzip 不可用，无法解包 native 库，跳过系统应用同步"
    exit 1
fi

FP=""
NEED_LIBS=0
NEED_KB=0
for f in $SRC_DATA; do
    if [ ! -f "$f" ]; then
        log "源文件不存在: $f"
        exit 1
    fi
    FP="$FP$(stat -c '%s:%Y' "$f" 2>/dev/null);"
    sz=$(stat -c %s "$f" 2>/dev/null)
    NEED_KB=$((NEED_KB + ${sz:-0} / 1024))
    libinfo=$(unzip -l "$f" "lib/$ABI_DIR/*.so" 2>/dev/null | awk '$4 ~ /^lib\// && $4 ~ /\.so$/ {c++; s+=$1} END {printf "%d %d\n", c+0, int(s/1024)}')
    n_cnt=$(printf '%s\n' "$libinfo" | awk '{print $1+0}')
    n_kb=$(printf '%s\n' "$libinfo" | awk '{print $2+0}')
    NEED_LIBS=$((NEED_LIBS + n_cnt))
    NEED_KB=$((NEED_KB + n_kb))
done

HAVE_LIBS=$(ls "$DEST/lib/$LIB_DIR"/*.so 2>/dev/null | wc -l | tr -d ' ')
if [ -f "$DEST/base.apk" ] && [ "$(cat "$DEST/.source" 2>/dev/null)" = "$FP" ]; then
    if [ "$NEED_LIBS" -eq 0 ] || [ "$HAVE_LIBS" -eq "$NEED_LIBS" ]; then
        log "$TARGET 系统应用副本已最新（libs=$HAVE_LIBS），跳过"
        exit 0
    fi
    log "$TARGET 副本缺少 native 库（$HAVE_LIBS/$NEED_LIBS），重新同步"
fi

OLD_KB=0
[ -d "$DEST" ] && OLD_KB=$(du -sk "$DEST" 2>/dev/null | awk '{print $1+0}')
FREE_KB=$(df -k "$MODDIR" 2>/dev/null | awk 'NR==2 {print $4+0; exit}')
NEED_TOTAL=$((NEED_KB + OLD_KB + 65536))
if [ "$FREE_KB" -gt 0 ] && [ "$FREE_KB" -lt "$NEED_TOTAL" ]; then
    log "存储空间不足：需约 $((NEED_TOTAL / 1024))MB，可用 $((FREE_KB / 1024))MB，跳过"
    exit 1
fi

mkdir -p "$ROOT" || { log "无法创建 $ROOT"; exit 1; }

STAGE="$MODDIR/.sysapp-stage"
OLD="$MODDIR/.sysapp-old"
rm -rf "$STAGE" "$OLD"
mkdir -p "$STAGE" || { log "无法创建暂存目录"; exit 1; }

for f in $SRC_DATA; do
    bn=${f##*/}
    if ! cp -f "$f" "$STAGE/$bn"; then
        log "复制失败: $f"
        rm -rf "$STAGE"
        exit 1
    fi
    s1=$(stat -c %s "$f" 2>/dev/null)
    s2=$(stat -c %s "$STAGE/$bn" 2>/dev/null)
    if [ "$s1" != "$s2" ]; then
        log "复制不完整: $bn（$s1 -> $s2）"
        rm -rf "$STAGE"
        exit 1
    fi
    chmod 644 "$STAGE/$bn" 2>/dev/null
done

if [ ! -f "$STAGE/base.apk" ]; then
    log "源 APK 中缺少 base.apk，中止"
    rm -rf "$STAGE"
    exit 1
fi

GOT_LIBS=0
if [ "$NEED_LIBS" -gt 0 ]; then
    mkdir -p "$STAGE/.lib"
    for f in $SRC_DATA; do
        unzip -o -q "$f" "lib/$ABI_DIR/*.so" -d "$STAGE/.lib" >/dev/null 2>&1
    done
    if [ -d "$STAGE/.lib/lib/$ABI_DIR" ]; then
        mkdir -p "$STAGE/lib/$LIB_DIR"
        mv "$STAGE/.lib/lib/$ABI_DIR"/*.so "$STAGE/lib/$LIB_DIR/" 2>/dev/null
        chmod 755 "$STAGE/lib/$LIB_DIR"/*.so 2>/dev/null
        GOT_LIBS=$(ls "$STAGE/lib/$LIB_DIR"/*.so 2>/dev/null | wc -l | tr -d ' ')
    fi
    rm -rf "$STAGE/.lib"
    if [ "$GOT_LIBS" -ne "$NEED_LIBS" ]; then
        log "native 库解包不完整: $GOT_LIBS/$NEED_LIBS，中止"
        rm -rf "$STAGE"
        exit 1
    fi
    chmod 755 "$STAGE/lib" "$STAGE/lib/$LIB_DIR" 2>/dev/null
fi
chmod 755 "$STAGE" 2>/dev/null

if [ -d "$DEST" ]; then
    if ! mv "$DEST" "$OLD"; then
        log "无法替换旧副本，中止"
        rm -rf "$STAGE"
        exit 1
    fi
fi
if ! mv "$STAGE" "$DEST"; then
    log "提交失败，恢复旧副本"
    if [ -d "$OLD" ]; then
        mv "$OLD" "$DEST"
    fi
    rm -rf "$STAGE"
    exit 1
fi
rm -rf "$OLD"
printf '%s' "$FP" > "$DEST/.source"
chmod 644 "$DEST/.source" 2>/dev/null
apk_cnt=$(ls "$DEST"/*.apk 2>/dev/null | wc -l | tr -d ' ')
log "已同步 $TARGET：APK ${apk_cnt} 个，native 库 ${GOT_LIBS} 个（$ABI_DIR）"
exit 0
