# BS2PRO-Controller (Linux Port)

> 飞智空间站 BS 1/2/2PRO 的第三方替代控制器 - Linux 移植版

**⚠️ 注意：这是原 Windows 版本的 Linux 移植版，仍在积极开发中**

这是一个基于 Wails + Go + Next.js 开发的跨平台桌面应用，用于控制飞智空间站 BS 1/2/2PRO 散热器设备，提供风扇控制、温度监控等功能。

## 📢 项目声明

本项目是基于 [TIANLI0/BS2PRO-Controller](https://github.com/TIANLI0/BS2PRO-Controller) 的 Linux 移植版本，特别针对 Arch Linux 优化。

### 与原版的区别
1. **平台支持**：专注于 Linux 系统（尤其是 Arch Linux）
2. **架构调整**：移除 Windows 特定组件（C# 桥接程序、命名管道等）
3. **系统集成**：适配 Linux 系统（systemd、udev 规则、桌面环境）
4. **构建系统**：使用 Makefile 替代 Windows 批处理脚本

### 当前状态
- ✅ 基础代码移植完成
- 🔄 IPC 层重构进行中（Windows 命名管道 → Unix 套接字）
- 🔄 温度监控系统适配进行中
- ⏳ Linux 系统集成待实现
- 📋 详细开发计划见 [LINUX-PORT-PLAN.md](LINUX-PORT-PLAN.md)

## 功能特性

- 🎮 **设备支持**：支持飞智 BS 1/2/2PRO 散热器
- 🌡️ **温度监控**：实时监控 CPU/GPU 温度（支持多种温度数据桥接方式）
- 💨 **风扇控制**：
  - 自动模式：根据温度自动调节风速
  - 学习控温：根据目标温度持续学习并微调曲线偏移
  - 手动模式：自定义固定风速
  - 曲线模式：自定义温度-风速曲线
- 📊 **可视化面板**：直观的温度和风速实时显示
- 🎯 **系统托盘**：支持最小化到系统托盘，后台运行
- 🚀 **开机自启**：可设置开机自动启动并最小化运行
- 🔧 **多进程架构**：GUI 和核心服务分离，稳定可靠
- 🛠️ **灯带配置**：支持灯带复杂调控，感谢群友 @Whether

## 系统架构

项目采用三进程架构：

- **GUI 进程** (`BS2PRO-Controller`)：提供用户界面，使用 Wails 框架
- **核心服务** (`BS2PRO-Core`)：后台运行，负责设备通信和温度监控
- **温度监控进程** (Linux 原生实现)：通过 Linux 系统接口获取温度数据

三个进程通过 IPC (进程间通信) 进行数据交互。Linux 版本使用 Unix 域套接字替代 Windows 命名管道。

## 技术栈

### 后端
- **Go 1.25+**：主要开发语言
- **Wails v2**：跨平台桌面应用框架
- **go-hid**：HID 设备通信（支持 Linux，需 udev 规则）
- **zap**：日志记录
- **Unix 域套接字**：Linux IPC 通信

### 前端
- **Next.js 16**：React 框架
- **TypeScript**：类型安全
- **Tailwind CSS 4**：样式框架
- **Recharts**：图表可视化

### Linux 温度监控
- **系统传感器接口**：`/sys/class/thermal`、`/sys/class/hwmon`
- **命令行工具集成**：`lm-sensors`、`nvidia-smi`
- **Go 系统库**：`github.com/shirou/gopsutil/v4`

## 开发环境要求

### 必需软件
- **Go 1.21+**：[下载地址](https://golang.org/dl/)
- **Node.js 18+**：[下载地址](https://nodejs.org/)
- **Bun**：快速的 JavaScript 运行时 [安装说明](https://bun.sh/)
- **Wails CLI**：安装命令 `go install github.com/wailsapp/wails/v2/cmd/wails@latest`

### Linux 系统依赖（Arch Linux）
```bash
# 基础开发工具
sudo pacman -S base-devel

# HID 设备访问依赖
sudo pacman -S libudev libusb

# 温度监控工具（可选，用于回退方案）
sudo pacman -S lm_sensors nvidia-utils

# 构建工具
sudo pacman -S make
```

### 其他发行版
- **Debian/Ubuntu**: `sudo apt install build-essential libudev-dev libusb-1.0-0-dev lm-sensors`
- **Fedora**: `sudo dnf install gcc libudev-devel libusb-devel lm_sensors`

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/KKTIME2024/BS2PRO-Controller-Linux.git
cd BS2PRO-Controller-Linux
```

### 2. 安装依赖

#### 安装 Go 依赖
```bash
go mod tidy
```

#### 安装前端依赖
```bash
cd frontend
bun install
cd ..
```

#### 安装 Linux 系统依赖（Arch Linux）
```bash
sudo pacman -S base-devel libudev libusb
```

### 3. 开发模式运行

```bash
# 启动 Wails 开发模式（包含热重载）
wails dev
```

### 4. 构建生产版本（Linux）

**注意**：Linux 构建系统正在开发中，目前使用 Wails 基础构建：

```bash
# 构建 Linux 版本
wails build -platform linux/amd64

# 或指定其他架构
wails build -platform linux/arm64
```

构建完成后，可执行文件位于 `build/bin/` 目录：
- `BS2PRO-Controller` - GUI 主程序
- `BS2PRO-Core` - 核心服务

**未来计划**：完整的 Makefile 构建系统和 systemd 服务集成。

## 项目结构

```
BS2PRO-Controller-Linux/
├── main.go                 # GUI 主程序入口
├── app.go                  # GUI 应用逻辑
├── wails.json             # Wails 配置文件
├── LINUX-PORT-PLAN.md     # Linux 移植开发计划
├── cmd/
│   └── core/              # 核心服务程序
│       ├── main.go        # 服务入口
│       └── app.go         # 服务逻辑
│
├── internal/              # 内部包
│   ├── autostart/         # 开机自启管理（待适配 Linux）
│   ├── bridge/            # 温度桥接通信（待重构）
│   ├── config/            # 配置管理
│   ├── device/            # HID 设备通信
│   ├── ipc/               # 进程间通信（Windows 命名管道 → Unix 套接字）
│   ├── logger/            # 日志模块
│   ├── temperature/       # 温度监控（待适配 Linux）
│   ├── tray/              # 系统托盘
│   ├── types/             # 类型定义
│   └── version/           # 版本信息
│
├── frontend/              # Next.js 前端
│   ├── src/
│   │   ├── app/
│   │   │   ├── components/    # React 组件
│   │   │   ├── services/      # API 服务
│   │   │   └── types/         # TypeScript 类型
│   │   └── ...
│   └── package.json
│
├── scripts/               # Linux 构建和安装脚本（待创建）
└── build/                 # 构建输出目录
```

### 已移除的 Windows 特定组件
- ❌ `build.bat` - Windows 构建脚本
- ❌ `build_bridge.bat` - 桥接程序构建脚本  
- ❌ `bridge/TempBridge/` - C# 温度桥接程序
- ❌ `cmd/core/winres/` - Windows 资源文件
- ❌ `build/windows/` - Windows 安装资源

## 使用说明

### 首次运行（Linux）

1. 构建或下载 Linux 版本的可执行文件
2. 运行 `./BS2PRO-Controller` 启动程序
3. 程序会自动启动核心服务 `./BS2PRO-Core`
4. 连接你的 BS2/BS2PRO 设备（USB 连接）
5. 程序会自动检测并连接设备（可能需要 udev 规则配置）

### 风扇控制模式

#### 自动模式
- 根据当前温度自动调节风速
- 适合日常使用

#### 手动模式
- 设置固定的风速档位（0-9档）
- 适合特定需求场景

#### 曲线模式
- 自定义温度-风速曲线
- 可添加多个控制点
- 实现精细化的温度控制

### 温度监控

程序支持多种温度监控方式：

1. **TempBridge**：通过 C# 桥接程序获取系统温度


### 系统托盘

- 点击托盘图标打开主窗口
- 右键菜单提供快捷操作
- 支持最小化到托盘后台运行

## 配置文件

配置文件位于 `~/.config/bs2pro-controller/config.json`（Linux）

主要配置项：
```json
{
  "autoStart": false,           // 开机自启
  "minimizeToTray": true,       // 关闭时最小化到托盘
  "temperatureSource": "auto",  // 温度数据源
  "updateInterval": 1000,       // 更新间隔（毫秒）
  "fanCurve": [...],           // 风扇曲线
  "fanMode": "auto"            // 风扇模式
}
```

## 日志文件

日志文件位于 `build/bin/logs/` 目录：
- `core_YYYYMMDD.log` - 核心服务日志
- `gui_YYYYMMDD.log` - GUI 程序日志

## 常见问题

### 设备无法连接？
1. 确保 BS2/BS2PRO 设备已正确连接到电脑
2. 检查设备驱动是否正常安装
3. 尝试重新插拔设备
4. 查看日志文件排查具体错误

### 温度无法显示？
1. 检查温度数据源设置
2. 如使用 TempBridge，确保 `bridge` 目录下的文件完整
3. 如使用 AIDA64/HWiNFO，确保软件正在运行并开启了共享内存功能

### 开机自启无效？（Linux）
1. 检查 systemd 用户服务是否启用：`systemctl --user status bs2pro-controller`
2. 检查桌面启动项：`~/.config/autostart/bs2pro-controller.desktop`
3. 确保有正确的执行权限

## 构建说明

### 版本号管理

版本号在 `wails.json` 的 `info.productVersion` 字段中定义，构建脚本会自动读取并嵌入到程序中。

### Linux 构建标志

构建时会注入版本信息：
```bash
# Linux 构建（无 -H=windowsgui 标志）
-ldflags "-X github.com/TIANLI0/BS2PRO-Controller/internal/version.BuildVersion=版本号"
```

### Linux 安装

当前支持以下安装方式：

1. **手动安装**：
   ```bash
   wails build -platform linux/amd64
   sudo cp build/bin/BS2PRO-Controller /usr/local/bin/
   sudo cp build/bin/BS2PRO-Core /usr/local/bin/
   ```

2. **systemd 用户服务**（待实现）：
   ```bash
   systemctl --user enable bs2pro-controller
   systemctl --user start bs2pro-controller
   ```

3. **桌面启动项**（待实现）：
   - 自动创建 `~/.config/autostart/bs2pro-controller.desktop`

## 贡献指南

欢迎提交 Issue 和 Pull Request！

**注意**：这是 Linux 移植版本，主要专注于 Linux 平台适配。对于 Windows 相关问题，请参考原项目。

1. Fork 本项目（https://github.com/KKTIME2024/BS2PRO-Controller-Linux）
2. 创建特性分支 (`git checkout -b feature/linux-port-feature`)
3. 提交更改 (`git commit -m 'Add Linux port feature'`)
4. 推送到分支 (`git push origin feature/linux-port-feature`)
5. 开启 Pull Request

## 开源许可

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 作者和贡献者

### 原项目作者
- **TIANLI0** - [GitHub](https://github.com/TIANLI0)
- Email: wutianli@tianli0.top

### Linux 移植维护者
- **KKTIME2024** - [GitHub](https://github.com/KKTIME2024)
- 项目地址：https://github.com/KKTIME2024/BS2PRO-Controller-Linux

## 致谢

### 原项目致谢
- [Wails](https://wails.io/) - 优秀的 Go 桌面应用框架
- [Next.js](https://nextjs.org/) - React 应用框架
- 飞智- BS2/BS2PRO 硬件设备

### Linux 移植特别感谢
- Linux 开源社区和各类硬件监控工具
- `lm-sensors` 项目提供硬件传感器支持
- Arch Linux 社区提供的优秀文档和工具

## 免责声明

本项目为第三方开源项目，与飞智官方无关。使用本软件产生的任何问题由用户自行承担。

---

⭐ 如果这个项目对你有帮助，请给一个 Star！
