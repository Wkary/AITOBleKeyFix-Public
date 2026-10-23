# 更新日志

## 0.0.1 — 2026-10-23

首个公开版本。

- 只保留“极速”档：开机写入 `ble_scan_background_mode=2`，低延迟间隔/窗口 100/100ms，开启常扫描
- AITO 加入 Doze 白名单并设为 active 待机桶
- 新增系统应用自动转换（默认开启），支持按 ABI 解包 native 库、文件指纹跳过、空间检查与失败回滚
- 移除 WebUI 与手动按钮，刷入重启即生效
- 日志统一到 `/data/adb/aitoblekeyfix.log`
- 新增 `SYSAPP=0` 开关，可恢复为普通用户应用
