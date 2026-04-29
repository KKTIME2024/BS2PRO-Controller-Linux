# BS2PRO-Controller Linux 移植 — 下一步计划

**更新日期**: 2026-04-29
**当前分支**: dev
**测试基础**: [2026-04-29 GUI 集成测试报告](2026-04-29_test-report_gui-integration.md)

---

## 当前状态

| 模块 | 状态 |
|------|------|
| IPC 通信、温度监控、智能控温、系统集成、打包系统、配置管理 | ✅ 完成 |
| GUI 构建 (Wails v2.12 + Next.js 16) | ✅ 完成 |
| 设备连接与数据监控 (HID/USB) | ✅ 正常 |
| HID 控制命令 (挡位/风扇/灯带) | ❌ P0 阻断 |
| BLE 支持 (BS1) | ❌ P1 |

---

## 一、无需硬件的开发任务

以下任务可在任何开发机上完成，不需要连接 BS2/BS2PRO 或 BS1 物理设备。

### 1.1 前端 UI 适配

| # | 任务 | 文件 | 优先级 |
|---|------|------|--------|
| 1 | 修改连接提示文案：`等待蓝牙连接…` → `等待设备连接…` | `frontend/src/app/components/DeviceStatus.tsx:255` | P1 |
| 2 | 修改空状态提示：`请将散热器通过蓝牙连接到电脑` → `请将散热器通过 USB 或蓝牙连接到电脑` | `frontend/src/app/components/DeviceStatus.tsx:336` | P1 |
| 3 | 添加设备类型选择 UI（USB / 蓝牙 / 自动检测） | `DeviceStatus.tsx` 连接按钮区域 | P2 |
| 4 | 添加连接进度指示器（spinner + 超时提示） | `DeviceStatus.tsx` | P2 |
| 5 | 清理 Windows 自启动残留代码 (`handleWindowsAutoStartChange`, `task_scheduler`, `registry`) | `ControlPanel.tsx:394-400` | P3 |

### 1.2 代码质量

| # | 任务 | 说明 |
|---|------|------|
| 6 | 搜索并清理所有 `Windows`/`.exe`/`Task Scheduler` 等残留字符串 | `grep -rn` 全仓库扫描 |
| 7 | 添加 Go 单元测试 | 覆盖 `internal/ipc`, `internal/config`, `internal/types` |
| 8 | 静态分析 | `go vet ./...` 确保无警告 |

### 1.3 CI/CD 与发布

| # | 任务 | 说明 |
|---|------|------|
| 9 | 创建 `.github/workflows/build.yml` | Go 编译 + 前端构建 + Wails GUI 构建 |

---

## 二、需要硬件的开发任务

以下任务必须连接物理设备才能进行开发和验证。

### 2.1 HID 控制命令修复（需要 BS2/BS2PRO USB）

**严重级别**: P0 阻断 — 这是唯一阻止项目可用的 bug。

**问题**: `m.device.Write()` 返回成功，但硬件不响应任何控制命令。根因假设为 Linux hidraw 与 Windows HID API 对 Report ID 字节 (`0x02`) 处理方式不同。

**步骤**:

| # | 任务 | 说明 |
|---|------|------|
| 12 | USB HID 抓包 (Linux) | `usbmon` + Wireshark 抓取 `SetManualGear` / `SetFanSpeed` 命令 |
| 13 | USB HID 抓包 (Windows) | 同命令在 Windows 上抓包作为对照组 |
| 14 | 字节序列对比 | 确认 Report ID `0x02` 在两平台的位置和处理差异 |
| 15 | 修改命令构造逻辑 | 根据对比结果调整 `internal/device/device.go` 中的命令发送 |
| 16 | 物理验证全部 6 个控制命令 | 挡位切换、风扇转速、挡位灯、智能启停、亮度、灯带 |

### 2.2 亮度控制支持中间值（需要 BS2/BS2PRO USB）

**严重级别**: P2

| # | 任务 | 说明 |
|---|------|------|
| 17 | 后端 `SetBrightness()` 支持 0-100% 线性亮度 | `device.go:753-764`，当前仅支持 0/100 二值 |

此项可与 HID 修复同步进行，因为都涉及 HID 命令格式。

### 2.3 BLE 支持恢复（需要 BS1 蓝牙）

**严重级别**: P1

**现状**: BS1 的 BLE 协议已完整逆向（`scripts/bs1.md`），Python `bleak` 读写脚本已存在。问题出在**传输层**而非协议层：BS1 在 Arch Linux 的系统蓝牙列表中完全不可见。

**根因分析**:

BS1 是为 Windows + 飞智官方客户端设计的 BLE 外设。其在 Linux 上不可见可能的原因：

1. **设备广播条件未知** — 可能仅在上电后短暂窗口广播，或需要特定触发（长按按键进入配对模式）
2. **BlueZ 扫描模式** — `bluetoothctl scan` 默认被动扫描，部分 BLE 设备只响应主动扫描（Active Scan）
3. **`tinygo.org/x/bluetooth` 兼容性** — 已知 Linux 版缺少 `Write` 方法（仅 `WriteWithoutResponse`），即使连接成功也无法发送控制命令

**步骤**:

| # | 任务 | 说明 |
|---|------|------|
| 18 | HCI 层低级别扫描 | `sudo hcitool lescan` / `sudo btmgmt find` 确认设备是否在物理层广播 |
| 19 | 确认 BS1 广播触发方式 | 查阅原厂说明书，或向原项目作者确认配对/广播触发条件 |
| 20 | 若 HCI 层可见：用 `godbus/dbus/v5` 直接调 BlueZ D-Bus API 实现 BLE 连接 | 绕过 `tinygo` 限制；完整 BLE GATT 协议已记录在 `scripts/bs1.md:260-276` |
| 21 | 备选：HCI socket 直连 | 如 D-Bus 方案不可行，直接构造 HCI ACL + ATT 包 |
| 22 | BS1 硬件验证 | 连接、数据监控（Handle 0x0026 Notify）、控制命令（Handle 0x0023 Write） |

### 2.4 设备兼容性验证（需要对应硬件）

| # | 任务 | 说明 |
|---|------|------|
| 23 | BS2PRO (PID 0x1002) 完整验证 | 代码已支持，无设备测试过 |
| 24 | AMD GPU 温度读取验证 | `roc-smi` 代码路径存在但未验证 |
| 25 | Intel GPU 温度读取验证 | `intel_gpu_top` 代码路径存在但未验证 |

---

## 推荐执行顺序

```
无需硬件（可立即开始）
├── 1.1 前端文案修正 (#1, #2)           ← 5分钟，立即见效
├── 1.1 Windows 残留清理 (#5, #6)       ← 30分钟
├── 1.1 连接方式选择 UI (#3, #4)        ← 2-3h
├── 1.2 Go 单元测试 (#7)                ← 3-4h
└── 1.3 CI/CD + AUR (#9-11)            ← 2-3h

需要硬件（需准备设备后依次进行）
├── 2.1 HID 抓包 + 修复 (#12-16)            ← P0 阻断，4-8h
├── 2.2 亮度中间值支持 (#17)                 ← 可与 HID 修复并行
├── 2.3 BLE: HCI 扫描 → BlueZ D-Bus (#18-22) ← 需 BS1 设备，先确认物理层可见
└── 2.4 其他设备验证 (#23-25)                ← 需对应硬件
```

---

*本计划基于 2026-04-29 手动测试报告生成，应随实际进展更新。*
