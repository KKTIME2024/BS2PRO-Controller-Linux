# BS2PRO-Controller Linux 移植 — 手动测试报告

**日期**: 2026-04-29  
**分支**: `feature/gui-build-and-integration-test`  
**测试环境**: Arch Linux (Wayland), Go 1.26.2, Wails v2.12.0, webkit2gtk-4.1  
**测试人员**: KK

---

## 1. 构建状态

| 组件 | 状态 | 耗时 | 产物 |
|------|------|------|------|
| 前端 (Next.js 16 + Turbopack) | 通过 | 4.4s | `frontend/.next/` |
| GUI (Wails v2.12 + Go) | 通过 | 21s | `build/bin/BS2PRO-Controller` (12MB) |
| Core (Go) | 通过 | — | `build/bin/BS2PRO-Core` (7.6MB) |

构建注意事项：需要在 Makefile 中通过 `PKG_CONFIG_PATH` 和 `CGO_LDFLAGS` 提供 webkit2gtk-4.0→4.1 兼容包装，因为 Arch Linux 已移除 webkit2gtk-4.0，仅保留 4.1。详情参见 `Makefile:12-16`。

## 2. GUI 启动测试

GUI 成功启动在 Wayland 会话上（XWayland 模式），核心服务作为子进程自动启动。日志摘要：

```
核心服务已启动，PID: 42334
核心服务已就绪
=== BS2PRO GUI 启动 ===
已连接到核心服务
=== BS2PRO GUI 启动完成 ===
```

IPC 通信（Unix Domain Socket @ `/tmp/bs2pro-controller-ipc.sock`）正常工作。

## 3. 设备连接测试

### 3.1 连接路径

当前系统支持双路径设备连接（参见 `internal/device/device.go:68-152`）：

| 路径 | 设备 | 方式 | Linux 状态 |
|------|------|------|-----------|
| Path A — HID (USB) | BS2 / BS2PRO | `go-hid` → `/dev/hidraw*` | **可用** |
| Path B — BLE | BS1 | `tinygo.org/x/bluetooth` → BlueZ | **不可用** |

### 3.2 BLE 问题

BLE 路径在 Linux 上无法正常工作，原因分析：

- `tinygo.org/x/bluetooth` 库依赖 Linux BlueZ D-Bus API
- 需 `bluetoothd` 服务运行、HCI 适配器可用、且用户有适当的 D-Bus 权限
- BS1 设备的 BLE 心跳机制（3 秒间隔，`ble.go:314-348`）在 Linux BlueZ 实现中存在稳定性问题
- **结论**：BS1 (BLE) 设备暂无法在 Linux 上连接

### 3.3 HID 连接行为

HID 路径在 BS2/BS2PRO 设备连接时表现如下：

- **数据监控**：正常。`monitorDeviceData()` (device.go:238-306) 以非阻塞模式读取 64 字节 HID Report，成功解析风扇转速、挡位状态、工作模式等
- **设备识别**：正常。成功区分 BS2 (0x1001) 与 BS2PRO (0x1002)
- **前端数据显示**：正常。温度、CPU/GPU 使用率、风扇 RPM、挡位、工作模式均正确渲染

## 4. 设备控制测试

### 4.1 测试结果

**结论：控制命令全部返回失败（False），设备不受前端控制。**

IPC 层面消息正常传递（GUI → Core → Device Manager），但最终 `m.device.Write()` 调用返回成功而设备实际未响应控制命令。

具体表现为：

| 功能 | 前端显示 | 实际控制 |
|------|---------|---------|
| 挡位切换 (SetManualGear) | 正常（UI 切换） | **无效**，硬件不响应 |
| 转速设置 (SetFanSpeed) | 正常 | **无效** |
| 挡位灯 (SetGearLight) | 正常（UI 切换） | **无效** |
| 智能启停 (SetSmartStartStop) | 正常 | **无效** |
| 亮度控制 (SetBrightness) | 正常 | **无效** |
| 灯带设置 (SetLightStrip) | — | **无效** |

### 4.2 根因分析

HID 控制命令格式为 23 字节输出报告，第一字节为 Report ID (`0x02`)。在 Linux 的 hidraw 驱动下，`write()` 系统调用会直接将整个缓冲区发送到设备，但有以下可能差异：

1. **Report ID 前缀处理差异**：Linux hidraw 和 Windows HID API 对输出报告中 Report ID 字节的解释可能不同。Windows 下 HID 类驱动自动剥离/添加 Report ID；Linux hidraw 直接透传，设备固件可能因此拒绝命令。

2. **设备固件期望**：BS2/BS2PRO 固件可能依赖 Windows 下 HID 协议栈的特定行为（如 Report ID 字节被驱动层移除后补充），而 Linux 的字节级直通与此不一致。

3. **23 字节补齐问题**：当前代码将命令补齐到 23 字节（HID Report Descriptor 定义的输出报告长度），但补齐方式（全零填充 `make([]byte, 23-len(cmd))`）可能与设备固件期望的填充值不符。

需通过 USB HID 抓包对比 Windows 和 Linux 下的控制命令字节序列，以确认具体差异点。

## 5. 前端 UI 问题

### 5.1 蓝牙导向的 UI 文案

`frontend/src/app/components/DeviceStatus.tsx` 中存在以下问题：

- **第 255 行**: `等待蓝牙连接…` — 对所有设备类型显示，BS2 用户产生困惑
- **第 336 行**: `请将散热器通过蓝牙连接到电脑` — 仅提及蓝牙，未提及 USB 有线连接

### 5.2 连接按钮行为

- "连接设备" 按钮触发 `ConnectDevice()` 绑定，实际执行 HID→BLE 串行尝试
- 没有设备选择 UI（BS2 USB vs BS1 BLE 之间选择）
- 连接成功/失败后的用户反馈仅通过 IPC 事件推送，UI 中没有进度指示器

### 5.3 亮度滑块

`SetBrightness()` (device.go:735-773) 仅支持二值控制 — 0%（关）和 100%（开），中间值直接返回 `false`。前端滑块 0-100 范围的中间值设置将无提示失败。

### 5.4 Windows 残留

前端 `controlPanel.tsx` 仍然引用 Windows 特定的自启动方法 (`task_scheduler`, `registry`)，这些在 Linux 上不可用。

## 6. 问题优先级汇总

| # | 问题 | 位置 | 严重级别 |
|---|------|------|---------|
| 1 | HID 控制命令在 Linux 上无效 | `internal/device/device.go` | **P0 — 阻断** |
| 2 | BLE 在 Linux 上不可用 | `internal/device/ble.go` | P1 |
| 3 | UI 文案仅提及"蓝牙"，缺少 USB 有线连接指引 | `frontend/src/app/components/DeviceStatus.tsx:255,336` | P1 |
| 4 | 亮度控制仅支持二值（0/100%） | `internal/device/device.go:753-764` | P2 |
| 5 | 缺少设备类型选择 UI | `frontend/src/app/components/DeviceStatus.tsx` | P2 |
| 6 | Windows 自启动引用残留 | `frontend/src/app/components/controlPanel.tsx:394-400` | P3 |

## 7. 建议的下一步工作

### Phase 1 — 解决 P0 问题（HID 控制）

1. 在 Linux 和 Windows 上分别对 BS2/BS2PRO 设备进行 USB HID 抓包（Wireshark/usbmon），对比 `SetManualGear` 和 `SetFanSpeed` 命令的字节序列
2. 确认 Report ID 字节 `0x02` 在两平台上的处理差异
3. 根据对比结果调整 `device.go` 中的命令构造逻辑，或添加平台条件编译
4. 验证 `go-hid` 库版本是否与系统 hidapi 库兼容

### Phase 2 — 解决 BLE 问题

1. 排查 `tinygo.org/x/bluetooth` 在 Linux 上的兼容性
2. 评估切换至原生 BlueZ D-Bus API（直接通过 `dbus` 包操作 BlueZ）的可行性
3. 调研替代方案：直接使用 HCI socket 进行 BLE 通信

### Phase 3 — 前端适配

1. 修改 DeviceStatus.tsx 文案，区分 USB 和蓝牙连接提示
2. 添加连接方式选择 UI（自动检测 vs 手动选择 USB/BLE）
3. 添加连接进度指示器
4. 清理 Windows 特定代码，添加 Linux 端条件逻辑
