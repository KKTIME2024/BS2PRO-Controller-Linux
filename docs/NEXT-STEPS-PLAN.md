# BS2PRO-Controller Linux 移植 — 下一步计划

**生成日期**: 2026-04-28
**当前分支**: main (clean)
**最新提交**: `f0f69c3` 完成硬件连接完整测试并修复系统适配问题

---

## 项目当前状态总览

### 已完成 (100%)

| 模块 | 状态 | 说明 |
|------|------|------|
| IPC 通信 | ✅ | Unix 域套接字, 完整请求/事件广播 |
| 温度监控 | ✅ | 多数据源: gopsutil, sensors, nvidia-smi, sysfs |
| 设备通信 | ✅ | go-hid 库, BS2 硬件验证通过 |
| 核心服务 | ✅ | 已编译, 设备控制/智能控温/灯带/快捷键均在 `build/bin/BS2PRO-Core` |
| 智能控温 | ✅ | 风扇曲线插值, 学习算法, 瞬态尖峰过滤 |
| 系统集成 | ✅ | systemd 用户服务, udev 规则, desktop 文件 |
| 打包系统 | ✅ | PKGBUILD, build-deb.sh, build-rpm.sh |
| 硬件测试 | ✅ | BS2 双向通信/物理响应验证通过 |
| 前端代码 | ✅ | Next.js + TypeScript + Tailwind, 组件完整 |
| 配置管理 | ✅ | 跨平台路径, JSON 配置文件 |

### 未完成 / 待办

| 项目 | 优先级 | 预估工时 |
|------|--------|----------|
| **GUI 构建** (Wails 前端) | 🔴 高 | 2-4h |
| 端到端集成测试 | 🔴 高 | 3-5h |
| BS2PRO 设备验证 | 🟡 中 | 1-2h |
| 残留 Windows 引用清理 | 🟡 中 | 1h |
| CI/CD 流水线 | 🟢 低 | 2-3h |
| AUR 提交 | 🟢 低 | 1h |
| 稳定性长测 | 🟢 低 | 持续 |

---

## 第一优先级: GUI 构建与端到端验证

当前状态: BS2PRO-Core 核心服务已编译且功能完整, 但 GUI 前端尚未构建,
导致无法进行完整的用户体验验证.

### 1.1 构建 GUI

**问题**: `build/bin/` 中只有 `BS2PRO-Core`, 没有 `BS2PRO-Controller` GUI.
Wails 构建需要 Node.js/Bun + Wails CLI.

**步骤**:
1. 确认 Wails CLI 已安装 (`wails doctor`)
2. 在 `frontend/` 中运行 `bun install` 确保依赖完整
3. 构建前端静态资源: `cd frontend && bun run build`
4. 使用 Wails 构建 GUI: `wails build` 或 `make build-gui`
5. 验证 `build/bin/BS2PRO-Controller` 可执行

### 1.2 端到端测试

1. 启动 `BS2PRO-Core`, 验证 IPC socket 创建 (`/tmp/bs2pro-controller-ipc.sock`)
2. 启动 `BS2PRO-Controller` GUI, 验证 IPC 连接
3. 连接 BS2 硬件, 验证:
   - 温度显示
   - 风扇转速读取
   - 自动模式 (温度→转速闭环)
   - 手动挡位切换
   - 挡位灯控制
   - 灯带配置
   - 系统托盘最小化/恢复
   - 快捷键功能
4. 配置文件读写验证 (`~/.config/bs2pro-controller/config.json`)
5. systemd 自启动验证 (`systemctl --user start bs2pro-controller`)

---

## 第二优先级: 代码质量与清理

### 2.1 残留 Windows 引用

搜索并修正以下模式:
- 日志消息中的 "Windows自启动" → "Linux自启动" (如 `cmd/core/app.go:192`)
- 注释/字符串中的 Windows 路径格式 (`\`, `.exe`)
- `windows.Options{WindowIsTranslucent: true}` 在 Linux 下是否有效

### 2.2 未测试的代码路径

- **BS2PRO (PID 0x1002)** — 代码已支持但无硬件测试
- **BS1 BLE 模式** — `internal/device/ble.go` 已实现但无设备验证
- **AMD GPU 温度** (roc-smi) — 代码路径存在但无 AMD GPU 验证
- **Intel GPU 温度** (intel_gpu_top) — 同上

### 2.3 前端验证

前端代码来自原 Windows 版, 需要确认:
- 所有 API 调用路径与 Linux IPC 后端一致
- Tailwind CSS 4 配置兼容 Linux 构建
- 无浏览器兼容性问题 (Wails WebView 在 Linux 上用 WebKitGTK)

---

## 第三优先级: 发布与运维

### 3.1 CI/CD

创建 `.github/workflows/build.yml`:
- Go 编译 (核心服务)
- 前端构建
- Wails GUI 构建
- DEB/RPM 打包
- 基础冒烟测试

### 3.2 AUR 提交

- 验证 PKGBUILD 在当前 Arch 系统上可正确构建
- 提交到 AUR: `bs2pro-controller` 或 `bs2pro-controller-bin`

### 3.3 文档补充

- 添加 `docs/TROUBLESHOOTING.md` (常见问题)
- 添加硬件兼容性列表
- 更新 README 中 "仍在积极开发中" 的状态描述

---

## 风险与阻塞点

| 风险 | 影响 | 缓解 |
|------|------|------|
| Wails CLI 未安装 | 无法构建 GUI | 安装: `go install github.com/wailsapp/wails/v2/cmd/wails@latest` |
| WebKitGTK 依赖缺失 | GUI 无法启动 | `sudo pacman -S webkit2gtk` |
| BS2PRO 无硬件 | 无法测试 BS2PRO | 先标记为 "实验性支持", 社区反馈后完善 |
| go-hid EINTR 错误 | 设备读取偶发失败 | 已有错误处理, 需长测观察 |

---

## 推荐工作顺序

1. **立即可做** (无硬件依赖):
   - 构建 GUI (`wails build`)
   - 清理残留 Windows 引用
   - 代码审查/静态分析

2. **需 BS2 硬件**:
   - 完整 GUI + Core 端到端测试
   - systemd 自启动测试
   - 长时间稳定性测试

3. **需其他硬件**:
   - BS2PRO 设备测试
   - BS1 BLE 设备测试
   - AMD/Intel GPU 温度测试

4. **发布前**:
   - CI/CD 搭建
   - AUR 提交
   - 文档定稿

---

*本计划基于 2026-04-28 仓库状态分析生成, 应随实际进展更新.*
