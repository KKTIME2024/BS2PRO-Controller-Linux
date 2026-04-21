# BS2PRO Controller Linux 移植开发计划

## 项目概述

本项目是基于原 Windows 版 BS2PRO-Controller 的 Linux 移植版本，特别针对 Arch Linux 优化。原项目地址：https://github.com/TIANLI0/BS2PRO-Controller

## 移植目标

1. 在 Linux 系统（尤其是 Arch Linux）上完全运行 BS2PRO-Controller
2. 提供与原 Windows 版本相同的核心功能
3. 适配 Linux 特有的系统集成（systemd、桌面环境等）
4. 维护代码与上游的可同步性

## 当前状态分析

### 高可行性部分（可重用）
- Wails 框架本身支持 Linux，GUI 层基本无需修改
- Go 语言核心业务逻辑可跨平台
- 前端（Next.js + TypeScript）完全兼容
- HID 库（go-hid）支持 Linux（需 udev 规则）

### 需要修改的中等难度部分
1. **IPC 进程通信** - 需从 Windows 命名管道改为 Unix 域套接字
2. **温度监控系统** - 需替换 Windows 特定实现
3. **构建系统** - 需创建 Linux 构建脚本
4. **开机自启** - Windows 注册表 → systemd 用户服务

### Windows 特定功能需要适配
- 管理员权限检查：Windows 管理员组 → root/sudo 权限检查
- 系统托盘：验证 fyne.io/systray 在 Linux 的兼容性
- 可执行文件引用：移除硬编码 `.exe` 扩展名

## 移植阶段计划

### 第一阶段：基础移植（1-2周）
**目标**：在 Linux 上构建并运行基础功能

#### 任务清单：
1. [ ] 创建 Linux 构建系统
   - 替换 `build.bat` 为 `build.sh` 或 Makefile
   - 设置跨平台构建配置

2. [ ] 修改 IPC 层使用 Unix 套接字
   - 修改 `internal/ipc/ipc.go` 移除 Windows 命名管道
   - 实现 Unix 域套接字通信
   - 移除 `github.com/Microsoft/go-winio` 依赖

3. [ ] 移除硬编码 Windows 路径和扩展名
   - 查找并替换所有 `.exe` 引用
   - 修改 Windows 特定路径（`%APPDATA%` → `~/.config`）

4. [ ] 基础 Linux 温度读取实现
   - 实现简单的 `/sys/class/thermal` 读取
   - 提供命令行工具（`sensors`、`nvidia-smi`）回退

5. [ ] 清除彻底不可用的 Windows 代码
   - 删除 C# 温度桥接程序 (`bridge/TempBridge/`)
   - 删除 Windows 资源文件 (`cmd/core/winres/`)
   - 删除 Windows 安装资源 (`build/windows/`)

### 第二阶段：功能完善（2-3周）
**目标**：完整功能实现和系统集成

#### 任务清单：
1. [ ] 完整 Linux 温度监控系统
   - 实现 CPU/GPU 温度读取（多数据源支持）
   - 集成 `lm-sensors` 和 `nvidia-smi`
   - 提供配置界面选择温度源

2. [ ] Linux 系统集成
   - systemd 用户服务自启动
   - 桌面启动项 (`~/.config/autostart/`)
   - 应用图标和桌面项

3. [ ] 权限管理和 udev 规则
   - 创建 udev 规则文件（HID 设备访问）
   - 安装脚本自动配置权限

4. [ ] 系统托盘集成验证
   - 测试 `fyne.io/systray` 在 Linux 的兼容性
   - 解决可能的依赖问题（DBus 等）

5. [ ] 跨平台配置管理
   - 统一配置文件路径
   - 平台特定配置选项

### 第三阶段：优化和打包（1-2周）
**目标**：发行版打包和用户体验优化

#### 任务清单：
1. [ ] Arch Linux 打包
   - 创建 PKGBUILD
   - 配置 systemd 服务文件
   - 桌面集成文件

2. [ ] 其他发行版支持（可选）
   - Debian/Ubuntu DEB 包
   - Fedora/RPM 包

3. [ ] 文档更新
   - 安装说明
   - 使用指南
   - 故障排除

4. [ ] 测试和验证
   - 多发行版测试
   - 硬件兼容性测试
   - 性能优化

## 技术实现细节

### 1. IPC 通信重构
**当前**：Windows 命名管道 (`\\.\pipe\BS2PRO-Controller-IPC`)
**目标**：Unix 域套接字 (`/tmp/bs2pro-ipc.sock` 或抽象命名空间)

修改文件：
- `internal/ipc/ipc.go` - 核心 IPC 实现
- `internal/bridge/bridge.go` - 温度桥接通信
- `main.go` - 核心服务启动

### 2. 温度监控替代方案
**当前**：C# 桥接程序 + LibreHardwareMonitor + PawnIO
**目标**：Go 原生实现 + Linux 系统接口

备选方案：
1. 直接读取 `/sys/class/thermal/thermal_zone*/temp`
2. 调用 `sensors` 命令解析输出
3. 使用 `nvidia-smi` 获取 GPU 温度
4. 使用 Go 库：`github.com/shirou/gopsutil/v4/sensors`

### 3. 构建系统重构
**当前**：`.bat` 批处理 + NSIS 安装程序
**目标**：Makefile + Shell 脚本 + systemd 服务

创建文件：
- `Makefile` - 主要构建脚本
- `build.sh` - 辅助构建脚本
- `install.sh` - 安装脚本
- `bs2pro-controller.service` - systemd 服务文件

### 4. 配置文件路径
**Windows**：`%APPDATA%\BS2PRO-Controller\config.json`
**Linux**：`~/.config/bs2pro-controller/config.json`

## 风险与挑战

### 技术风险
1. **HID 设备权限**：Linux 需要正确的 udev 规则
2. **温度读取准确性**：不同硬件/内核版本的传感器接口差异
3. **系统托盘兼容性**：不同桌面环境的系统托盘实现

### 管理风险
1. **上游代码同步**：保持与 Windows 版本的功能同步
2. **用户支持**：Linux 环境多样性带来的支持复杂性

## 成功标准

1. [ ] 在 Arch Linux 上成功构建并运行
2. [ ] 核心功能（风扇控制、温度监控）正常工作
3. [ ] 支持 systemd 自启动和桌面集成
4. [ ] 提供完整的安装和配置文档
5. [ ] 至少支持一种常见 Linux 发行版的打包

## 维护策略

### 分支管理
- `main`：稳定版本（Linux 移植完成后的版本）
- `dev`：开发分支（Linux 移植进行中）
- `feature/*`：功能分支（具体功能开发）

### 上游同步
- 定期从原仓库获取更新
- 选择性合并 bug 修复和新功能
- 保持 Linux 特定修改的隔离性

## 贡献指南

### 开发环境设置
1. Go 1.21+
2. Node.js 18+ 和 Bun
3. Wails CLI：`go install github.com/wailsapp/wails/v2/cmd/wails@latest`
4. Linux 开发依赖：`libudev-dev`、`libusb-1.0-0-dev` 等

### 构建命令
```bash
# 开发模式
make dev

# 构建
make build

# 安装
make install

# 清理
make clean
```

### 测试
```bash
# 运行测试
make test

# 开发模式运行
make run
```

---

*本计划将根据实际开发进展进行更新和调整。*

**最后更新**：2026-04-21  
**负责人**：KKTIME2024  
**项目状态**：开发中