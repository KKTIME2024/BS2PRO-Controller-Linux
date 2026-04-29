# BS2PRO-Controller-Linux 项目记忆

## 项目概述
- **名称**: BS2PRO-Controller-Linux - 飞智空间站 BS 1/2/2PRO 的第三方替代控制器 Linux 移植版
- **类型**: 跨平台桌面应用 (Go + Wails + Next.js)
- **功能**: 控制飞智 BS 1/2/2PRO 散热器设备，提供风扇控制、温度监控等功能
- **状态**: Linux 移植完成，硬件连接测试成功 (2026-04-25)

## 核心技术栈
### 后端
- **语言**: Go 1.21+ (主要), Go modules
- **框架**: Wails v2 (桌面应用框架)
- **设备通信**: go-hid (HID 设备访问，需要 udev 规则)
- **IPC通信**: Unix 域套接字 (替代 Windows 命名管道)
- **日志**: zap 日志库
- **温度监控**: Linux 原生实现 (通过 `/sys/class/thermal`、`/sys/class/hwmon`)

### 前端
- **框架**: Next.js 16 + React
- **语言**: TypeScript
- **样式**: Tailwind CSS 4
- **图表**: Recharts
- **包管理**: Bun (快速 JavaScript 运行时)

## 项目架构
三进程架构:
1. **GUI 进程** (`BS2PRO-Controller`): 用户界面，使用 Wails 框架
2. **核心服务** (`BS2PRO-Core`): 后台运行，负责设备通信和温度监控
3. **温度监控进程**: Linux 原生实现，通过系统接口获取温度数据

## 关键目录结构
```
BS2PRO-Controller-Linux/
├── main.go                    # GUI 主程序入口
├── app.go                     # GUI 应用逻辑
├── cmd/core/                  # 核心服务程序
│   ├── main.go               # 服务入口
│   └── app.go                # 服务逻辑
├── internal/                  # 内部包
│   ├── device/               # HID 设备通信 (Linux 适配)
│   ├── temperature/          # 温度监控 (Linux 原生实现)
│   ├── ipc/                  # 进程间通信 (Unix 域套接字)
│   ├── config/               # 配置管理
│   └── tray/                 # 系统托盘 (fyne.io/systray)
├── frontend/                 # Next.js 前端
│   ├── src/app/              # React 组件和页面
│   └── package.json
├── scripts/                  # Linux 构建和安装脚本
├── build/                    # 构建输出
│   ├── bin/                 # 可执行文件
│   ├── bs2pro-controller.user.service  # systemd 用户服务
│   └── 99-bs2pro-controller.rules      # udev 规则
└── Makefile                 # 构建和安装管理
```

## 开发命令
### 常用开发命令
```bash
# 开发模式运行 (热重载)
wails dev
# 或使用 Makefile
make dev

# 构建项目
make build
# 分别构建
make build-core    # 构建核心服务
make build-gui     # 构建 GUI 程序

# 运行构建的程序
make run

# 清理
make clean
```

### 安装和系统集成
```bash
# 用户安装 (推荐)
make user-install
make install-systemd

# 系统范围安装 (需要 root)
sudo make install

# 卸载
make uninstall-systemd
make user-uninstall
```

## Linux 系统依赖
### Arch Linux
```bash
sudo pacman -S base-devel libudev libusb lm_sensors nvidia-utils
```

### 其他发行版
- **Debian/Ubuntu**: `sudo apt install build-essential libudev-dev libusb-1.0-0-dev lm-sensors`
- **Fedora**: `sudo dnf install gcc libudev-devel libusb-devel lm_sensors`

## 硬件访问和权限
### 关键 udev 规则
- 位置: `/etc/udev/rules.d/99-bs2pro-controller.rules`
- 内容: 允许普通用户访问 HID 设备
- 安装: `make install-systemd` 会自动安装

### HID 设备访问
- 需要 udev 规则配置设备权限
- 设备 VID: 0x3521, PID: 0x0102
- HID 报告格式: 64 字节数据包

## 系统服务管理
### Systemd 用户服务
```bash
# 检查状态
systemctl --user status bs2pro-controller

# 启动/停止
systemctl --user start bs2pro-controller
systemctl --user stop bs2pro-controller

# 启用/禁用开机自启
systemctl --user enable bs2pro-controller
systemctl --user disable bs2pro-controller

# 查看日志
journalctl --user -u bs2pro-controller -f
```

### 服务文件
- 用户服务: `~/.config/systemd/user/bs2pro-controller.service`
- 桌面文件: `~/.config/autostart/bs2pro-controller.desktop`

## 配置文件
- **位置**: `~/.config/bs2pro-controller/config.json`
- **主要配置项**:
  - `autoStart`: 开机自启
  - `minimizeToTray`: 关闭时最小化到托盘
  - `temperatureSource`: 温度数据源 (auto, linux, nvidia, etc.)
  - `updateInterval`: 更新间隔 (毫秒)
  - `fanCurve`: 风扇曲线配置
  - `fanMode`: 风扇模式 (auto, manual, curve, learn)

## 日志文件
- **位置**: `build/bin/logs/`
- **文件**:
  - `core_YYYYMMDD.log` - 核心服务日志
  - `gui_YYYYMMDD.log` - GUI 程序日志

## 测试相关
### 硬件测试脚本
```bash
# 基础连接测试
python3 test/test_bs2_connection.py

# 自动功能测试
python3 test/auto_test_bs2.py

# 详细验证
python3 test/detailed_verification.py

# 重启验证
bash test/scripts/verify_after_reboot.sh
```

### 测试文档
- `docs/2026-04-29_test-report_gui-integration.md` - GUI集成测试报告（最新，含已知问题）
- `docs/2026-04-25_test-report_hardware-bs2.md` - 硬件测试完整报告
- `docs/guide_hardware-test.md` - 测试流程指南

## 发行版打包
### 支持格式
- **Arch Linux**: AUR (提供 PKGBUILD)
- **Debian/Ubuntu**: DEB 包 (`./scripts/build-deb.sh`)
- **Fedora/RHEL**: RPM 包 (`./scripts/build-rpm.sh`)

### 打包内容
- 预编译二进制文件
- systemd 用户服务
- udev 规则
- 桌面菜单项
- 安装/卸载脚本

## 已知问题和解决方案
### 1. 设备无法连接
1. 检查设备是否正确连接
2. 验证 udev 规则是否生效 `ls -la /dev/hidraw*`
3. 检查用户权限 `groups $USER`
4. 查看日志文件排查错误

### 2. 温度无法显示
1. 检查 lm-sensors 是否安装 `sensors`
2. 检查 NVIDIA GPU 温度 `nvidia-smi`
3. 验证温度数据源配置

### 3. 开机自启无效
1. 确保 systemd 用户会话已启用 `loginctl enable-linger $USER`
2. 检查服务状态 `systemctl --user status bs2pro-controller`
3. 重新登录或重启系统

## 硬件测试验证
### ✅ 已验证的功能
- 设备连接: USB/HID 枚举和识别
- 双向通信: 命令发送和响应接收
- 物理响应: 档位灯控制和风扇转速变化
- 实时监控: 风扇状态数据包读取
- 权限持久: udev 规则配置持久生效

### 📋 实际测试经验 (2026-04-26)
#### 设备识别
- **实际设备 VID:PID**: 0x37D7:0x1001 (飞智 BS2)
- **设备路径**: 动态分配 (如 `/dev/hidraw6`，非固定 `/dev/hidraw7`)
- **udev 规则生效**: 使用 `uaccess` 标签比 `plugdev` 组更可靠
- **权限验证**: 设备文件权限应为 `crw-rw-rw-` (0666)

#### 系统集成问题解决
1. **systemd 宏使用**:
   - 正确: `%H` (用户主目录)
   - 错误: `%h` (无效宏) 或硬编码 `/home/username`
   - 服务文件应使用: `ExecStart=%H/.local/bin/BS2PRO-Core --autostart`

2. **设备动态检测**:
   - 避免硬编码设备路径 `/dev/hidraw7`
   - 推荐使用 Python `hid.enumerate()` API 基于 VID/PID 检测
   - 或使用通配符 `/dev/hidraw*` 匹配所有可能设备

3. **常见错误**:
   - `Interrupted system call`: HID 读取超时，需调整读取参数
   - `Failed to read icon format image`: 系统托盘图标格式可能不兼容 (Windows ICO 格式在 Linux 系统托盘库中的问题)
   - `plugdev group not found`: 使用 `uaccess` 标签替代组权限
   - `%h/.local/bin/BS2PRO-Core: No such file or directory`: systemd 宏使用错误，应使用 `%H`

#### 测试数据包格式
- **命令发送**: 24字节数据包，以 `5AA5` 开头
- **设备响应**: 数据包以 `03 5A A5` 开头
- **状态字节**: `EF` 表示设备状态信息
- **风扇控制**: 成功验证档位切换（静音模式/标准模式）

#### 跨发行版注意事项
- **Arch Linux**: 默认无 `plugdev` 组，udev 规则需使用 `uaccess`
- **权限生效**: 需要重新加载 `sudo udevadm control --reload-rules` 并触发事件
- **用户会话**: systemd 用户服务需要图形会话环境 (DISPLAY, XAUTHORITY)

### 🔧 推荐的修复方案
1. **更新测试脚本**: 使用动态设备检测
2. **修正 systemd 配置**: 使用正确的 `%H` 宏
3. **udev 规则优化**: 使用 `TAG+="uaccess"` 替代 `GROUP="plugdev"`
4. **错误处理增强**: 处理 HID 读取中断和超时

## 开发注意事项
1. **移除的 Windows 组件**: 所有 Windows 特定代码已移除，包括 C# 桥接程序、.bat 脚本等
2. **Linux 适配**: 全部使用 Linux 原生接口替代 Windows API
3. **权限管理**: 需要关注 udev 规则和用户权限配置
4. **温度监控**: 支持多种温度数据源 (Linux 系统传感器、lm-sensors、nvidia-smi)
5. **系统集成**: 完整支持 systemd、desktop 文件、应用菜单

## 贡献说明
- 项目地址: https://github.com/KKTIME2024/BS2PRO-Controller-Linux
- 这是 Linux 移植版本，专注于 Linux 平台适配
- Windows 相关问题请参考原项目: https://github.com/TIANLI0/BS2PRO-Controller

## 许可证
- **许可证**: MIT License
*文件创建时间: 2026-04-26*