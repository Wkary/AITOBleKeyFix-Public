# AITO Ble Key Fix

问界 / AITO 蓝牙车钥匙加速模块，适用于 Magisk、KernelSU、SukiSU。

开机自动把系统 BLE 扫描切到低延迟档，将 AITO 加入 Doze 白名单并设为 active 待机桶，并可自动把已安装的 AITO 同步为系统应用。无 WebUI，刷入后重启生效。

> 当前版本 **0.0.1**，仅保留“极速”档。

## 功能

- **BLE 低延迟**：写入 `ble_scan_background_mode=2`、`ble_scan_low_latency_interval_ms=100`、`ble_scan_low_latency_window_ms=100`、`ble_scan_always_enabled=1`
- **保活**：对 `app.huawei.auto`、`app.huawei.motor` 中已安装的包执行 `cmd deviceidle whitelist +<pkg>` 与 `am set-standby-bucket <pkg> active`
- **系统应用转换**：默认开启，把已安装的 AITO 同步到模块内 `system/app/<包名>/`，重启后由系统识别为系统应用
- **日志**：`/data/adb/aitoblekeyfix.log`（安装日志为 `/data/adb/aitoblekeyfix.install.log`）

## 安装

1. 从 [Releases](../../releases) 下载 `AITOBleKeyFix-v0.0.1.zip`
2. 在 Magisk / KernelSU / SukiSU 中刷入
3. 重启一次

安装阶段会尝试预置系统应用副本。若提示预置失败，首次开机会自动重试；日志显示副本刚复制完成时，再重启一次让系统识别。

## 系统应用转换

`config` 中的 `SYSAPP=1`（默认）表示开机自动同步：

- 只复制当前已安装的 APK 与设备 ABI 对应的 native 库，不修改原安装包
- AITO 更新后，下次开机会按文件大小与修改时间自动重新同步
- AITO 3.0.2.320 实测副本约 600MB，需要足够的可用空间

改成 `SYSAPP=0` 并重启即可恢复为普通用户应用，模块会删除已同步的副本。

## 注意

- BLE 扫描参数是全局的，所有应用共享，待机会略增耗电。
- 本模块会修改系统设置与应用安装形态，请确认了解风险后使用。
- 开发环境为 HyperOS + AITO 3.0.2.320，其他系统与版本请自测。
- 卸载模块会移除系统应用副本；已写入的 BLE 参数与 Doze 白名单不会自动还原。

## 作者

@北梦南城丶
