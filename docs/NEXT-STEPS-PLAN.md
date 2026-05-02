# BS2PRO-Controller Linux 移植 — 下一步计划

**更新日期**: 2026-05-02
**当前分支**: dev
**测试基础**: [2026-04-29 GUI 集成测试报告](2026-04-29_test-report_gui-integration.md)

---

## 当前状态

| 模块 | 状态 |
|------|------|
| IPC 通信、温度监控、智能控温、系统集成、打包系统、配置管理 | ✅ 完成 |
| GUI 构建 (Wails v2.12 + Next.js 16) | ✅ 完成 |
| 设备连接与数据监控 (HID/USB) | ✅ 正常 |
| 前端 Linux 适配（文案、自启动、设备选择 UI、连接进度） | ✅ 完成 |
| Go 单元测试（types/config/ipc, 28 tests） | ✅ 完成 |
| CI/CD（GitHub Actions build workflow） | ✅ 完成 |
| HID 控制命令 (挡位/风扇/灯带) | ✅ 已修复 (2026-05-02) |
| BLE 支持 (BS1) | ❌ P1 |

---

## 一、无需硬件的开发任务 ✅ 全部完成

以下任务于 2026-04-30 全部完成。

### 1.1 前端 UI 适配

| # | 任务 | 状态 |
|---|------|------|
| 1 | 修改连接提示文案：`等待蓝牙连接…` → `等待设备连接…` | ✅ |
| 2 | 修改空状态提示：`请将散热器通过蓝牙连接到电脑` → `请将散热器通过 USB 或蓝牙连接到电脑` | ✅ |
| 3 | 添加设备类型选择 UI（USB / 蓝牙 / 自动检测） | ✅ |
| 4 | 添加连接进度指示器（spinner + 超时提示） | ✅ |
| 5 | 清理 Windows 自启动残留（`handleWindowsAutoStartChange` → `handleLinuxAutoStartChange`） | ✅ |

### 1.2 代码质量

| # | 任务 | 状态 |
|---|------|------|
| 6 | 搜索并清理所有 Windows 残留字符串 | ✅ |
| 7 | 添加 Go 单元测试（`internal/types`: 10, `internal/config`: 6, `internal/ipc`: 12） | ✅ 28 tests |
| 8 | 静态分析 `go vet ./...` | ✅ 零警告 |

### 1.3 CI/CD

| # | 任务 | 状态 |
|---|------|------|
| 9 | 创建 `.github/workflows/build.yml`（Core / Frontend / GUI 三 job） | ✅ |

---

## 二、硬件连接准备

以下步骤用于在 Linux 上正确识别和访问 BS2/BS2PRO 设备。

### 2.0 物理连接与权限配置

**设备信息**:

| 参数 | 值 |
|------|-----|
| 厂商 ID (VID) | `0x37D7` (飞智/Flydigi) |
| 产品 ID (PID) | `0x1001` (BS2) / `0x1002` (BS2PRO) |
| 接口类型 | USB HID (hidraw) |
| 连接方式 | USB 有线 |

**步骤**:

1. **物理连接**: 使用 USB 数据线将 BS2/BS2PRO 设备连接到电脑 USB 端口
2. **验证设备识别**:
   ```bash
   lsusb | grep -i 37d7          # 应显示 Flydigi 设备
   dmesg | grep -i hidraw | tail  # 应显示 hidraw 设备节点创建
   ```
3. **安装 udev 规则**（解决 `/dev/hidraw*` 权限问题）:
   ```bash
   sudo cp build/99-bs2pro-controller.rules /etc/udev/rules.d/
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```
   规则内容：匹配 `SUBSYSTEM=="hidraw"` + `ATTRS{idVendor}=="37d7"`，设置 `MODE="0666"`，无需 root 即可读写。
4. **验证权限**:
   ```bash
   ls -la /dev/hidraw*            # 飞智设备应显示 crw-rw-rw- 权限
   ```
5. **快速权限修复**（如 udev 规则未生效）:
   ```bash
   sudo chmod 666 /dev/hidraw*    # 临时方案
   ```
   或运行 `test/scripts/fix_hid_permissions.sh` 交互式修复脚本。
6. **测试 HID 通信**:
   ```bash
   python3 test/test_hid_detect.py                           # Python 检测脚本
   go run scripts/hid_controller.go                          # Go 独立测试工具
   python3 test/test_bs2_connection.py                       # 连接测试
   ```
7. **确认数据读取正常**: 连接成功后应能持续接收到温度、风扇转速等遥测数据（设备主动上报，无需发送命令）。

> **当前状态 (2026-05-02)**: BS2 设备已通过 USB 有线连接至本机，hidraw 设备节点正常识别。HID 控制命令已修复（根因：移除错误的 `0x02` Report ID 前缀），数据读写通道均已验证可用。

---

## 三、需要硬件的开发任务

以下任务必须在硬件连接正常的基础上进行开发和验证。

### 3.1 HID 控制命令修复（需要 BS2/BS2PRO USB）✅ 已修复 (2026-05-02)

**严重级别**: P0 阻断 — 已解决。

**根因**: `device.go` 中所有 HID 控制命令错误地添加了 `0x02` Report ID 前缀。BS2 设备的 Output Report 不需要 Report ID，命令应从 `5A A5` 直接开始。Linux hidraw 的 `write()` 将数据原样发送，多余的 `0x02` 导致设备无法解析命令。

**修复**: 移除 `device.go` 中所有命令的 `0x02` 前缀（10 处命令字节切片 + `SetManualGear` 的 prepend 逻辑）。

**步骤**:
| # | 任务 | 状态 |
|---|------|------|
| 12 | 诊断 Report ID 前缀问题 | ✅ Python 对比测试确认 |
| 13 | 移除所有 `0x02` 前缀 | ✅ `device.go` 已修复 |
| 14 | 物理验证：挡位灯 ON/OFF | ✅ 正常 |
| 15 | 物理验证：风扇转速 2000 RPM | ✅ 遥测确认 RPM=2000 |
| 16 | 物理验证：亮度 0%/100% | ✅ 正常 |
| 17 | 物理验证：智能启停 | ✅ 设备回显确认 |
| 18 | 物理验证：通电自启动 | ✅ 设备回显确认 |
| 19 | 物理验证：手动挡位切换 | ✅ 正常 |

### 3.2 亮度控制支持中间值（需要 BS2/BS2PRO USB）✅ 已完成 (2026-05-02)

**严重级别**: P2 — 已实现。

**命令格式**: `5A A5 43 03 <val:0x01-0xFF> <checksum>`，值域 1-255 全部被设备接受。0% 使用 `5A A5 47 0D 1C 00 FF` 关闭显示屏。

**实现**: `device.go:SetBrightness()` 支持 0-100% 全范围。
- 0% → 关闭显示 (0x47 命令)
- 1-100% → 线性映射到 0x01-0xFF，checksum = (sum of bytes + 1) & 0xFF

| # | 任务 | 状态 |
|---|------|------|
| 20 | 探测亮度命令格式（值域扫描 0x00-0xFF） | ✅ 确定 0x43/0x03 格式 |
| 21 | 修改 `SetBrightness()` 支持 0-100% | ✅ 已实现 |
| 22 | 物理验证（10/30/60/90/100/3/0%） | ✅ 正常 |

### 3.3 BLE 支持恢复（需要 BS1 蓝牙）

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

### 3.4 设备兼容性验证（需要对应硬件）

| # | 任务 | 说明 |
|---|------|------|
| 23 | BS2PRO (PID 0x1002) 完整验证 | 代码已支持，无设备测试过 |
| 24 | AMD GPU 温度读取验证 | `roc-smi` 代码路径存在但未验证 |
| 25 | Intel GPU 温度读取验证 | `intel_gpu_top` 代码路径存在但未验证 |

---

## 推荐执行顺序

```
无需硬件 ✅ 全部完成 (2026-04-30)
├── 1.1 前端文案修正 (#1, #2)              ✅ 733c718
├── 1.1 Windows 残留清理 (#5, #6)          ✅ 733c718
├── 1.1 连接方式选择 UI + 进度指示器 (#3, #4) ✅ f87621e
├── 1.2 Go 单元测试 28 tests (#7)          ✅ bf76ccd
└── 1.3 CI/CD workflow (#9)               ✅ e1c0280

需要硬件（下一步）
├── 2.0 硬件连接准备（USB + udev 权限）        ✅ 2026-05-02
├── 3.1 HID 抓包 + 修复 (#12-19)            ✅ 已修复 2026-05-02
├── 3.2 亮度中间值支持 (#20-22)               ✅ 已完成 2026-05-02
├── 3.3 BLE: HCI 扫描 → BlueZ D-Bus (#18-22) ← 需 BS1 设备
└── 3.4 其他设备验证 (#23-25)                ← 需对应硬件
```

---

*本计划基于 2026-04-29 手动测试报告生成，应随实际进展更新。*
