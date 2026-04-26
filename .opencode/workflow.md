# BS2PRO-Controller-Linux 工作流程

## 项目初始化工作流

### 1. 环境检查
```bash
# 检查必需软件版本
go version          # 需要 Go 1.21+
node --version      # 需要 Node.js 18+
bun --version       # 需要 Bun
wails version       # 需要 Wails CLI

# 检查系统依赖
lsb_release -a      # 查看发行版信息
ldconfig -p | grep libudev    # 检查 libudev
ldconfig -p | grep libusb     # 检查 libusb
```

### 2. 依赖安装
```bash
# 1. 克隆项目
git clone https://github.com/KKTIME2024/BS2PRO-Controller-Linux.git
cd BS2PRO-Controller-Linux

# 2. 安装 Go 依赖
go mod tidy
go mod download

# 3. 安装前端依赖
cd frontend
bun install
cd ..

# 4. 安装系统依赖 (Arch Linux 为例)
sudo pacman -S base-devel libudev libusb lm_sensors nvidia-utils

# 5. 安装 Wails CLI (如未安装)
go install github.com/wailsapp/wails/v2/cmd/wails@latest
```

### 3. 开发环境验证
```bash
# 验证环境配置
make dev-check      # 检查基本环境

# 运行开发服务器
wails dev
# 或
make dev

# 验证 HID 设备权限
python3 test/test_bs2_connection.py
```

## 日常开发工作流

### 前端开发模式
```bash
# 启动前端开发服务器 (热重载)
cd frontend
bun dev
# 访问: http://localhost:3000

# 或使用完整 Wails 开发模式
wails dev
```

### 后端开发模式
```bash
# 单独构建和测试核心服务
make build-core
./build/bin/BS2PRO-Core --test

# 运行核心服务调试模式
./build/bin/BS2PRO-Core --debug
```

### 代码检查和格式化
```bash
# Go 代码格式化
gofmt -w .

# 前端代码检查
cd frontend
bun lint
bun format

# 构建检查
make build
```

## 测试工作流

### 硬件连接测试
```bash
# 1. 基础设备连接测试 (动态检测设备)
python3 test/test_bs2_connection.py

# 2. USB 设备枚举检查 (实际BS2 VID:PID = 0x37D7:0x1001)
lsusb | grep -i "37d7:"
# 或使用详细模式查看设备信息
lsusb -d 37d7:

# 3. HID设备权限检查
ls -la /dev/hidraw*  # 检查所有hidraw设备权限

# 4. 动态设备检测测试
python3 test/test_hid_detect.py  # 高级设备检测脚本

# 5. 权限验证和udev规则重载
groups $USER
sudo udevadm control --reload-rules
sudo udevadm trigger

# 6. 验证设备访问 (Python API)
python3 -c "import hid; print([d for d in hid.enumerate() if d.get('vendor_id') == 0x37D7])"
```

### 设备检测和动态路径处理
```bash
# 1. 动态检测设备编号（避免硬编码 /dev/hidraw7）
# 使用通配符匹配所有hidraw设备
ls /dev/hidraw* 2>/dev/null | head -5

# 2. 基于VID/PID的设备查找
# Python hid API 自动查找BS2设备 (VID:0x37D7, PID:0x1001/0x1002)
python3 -c "
import hid
for d in hid.enumerate():
    if d.get('vendor_id') == 0x37D7:
        pid = d.get('product_id', 0)
        name = 'BS2PRO' if pid == 0x1002 else 'BS2' if pid == 0x1001 else 'Unknown'
        print(f'Found: {name} at {d.get(\"path\", \"unknown\")}')"

# 3. 设备权限修复（动态路径）
# 修复所有hidraw设备权限（临时方案）
sudo chmod 666 /dev/hidraw* 2>/dev/null || true

# 4. 验证udev规则生效
sudo udevadm test $(udevadm info -q path -n /dev/hidraw0 2>/dev/null) 2>&1 | grep -i "mode\|permission"

# 注意：设备路径可能会变化，推荐使用基于VID/PID的动态检测
```

### 功能测试
```bash
# 自动功能测试
python3 test/auto_test_bs2.py

# 详细验证测试
python3 test/detailed_verification.py

# 重启验证
bash test/scripts/verify_after_reboot.sh
```

### 系统服务测试
```bash
# 1. 安装 systemd 服务 (注意需要使用正确的systemd宏)
make install-systemd
# 手动检查服务文件中的宏是否正确:
# cat ~/.config/systemd/user/bs2pro-controller.service | grep ExecStart
# 应该使用 %H (用户主目录) 而不是 %h 或硬编码路径

# 2. 测试服务启动
systemctl --user start bs2pro-controller
systemctl --user status bs2pro-controller

# 3. 检查日志
journalctl --user -u bs2pro-controller -f

# 4. 测试自启动
systemctl --user enable bs2pro-controller
# 重启后验证服务自动启动

# 5. 服务调试 (如果服务无法启动)
systemctl --user daemon-reload
journalctl --user -u bs2pro-controller --since "1 minute ago" --no-pager
# 常见问题: 确保二进制文件在 ~/.local/bin/ 且可执行
```

## 构建和打包工作流

### 常规构建
```bash
# 1. 清理旧构建
make clean

# 2. 构建所有组件
make build

# 3. 验证构建结果
ls -la build/bin/
file build/bin/BS2PRO-Controller
file build/bin/BS2PRO-Core

# 4. 运行测试
make run
```

### 发行版打包
```bash
# Arch Linux (AUR)
make arch-package

# Debian/Ubuntu (DEB)
./scripts/build-deb.sh
# 检查生成的 DEB 包
ls -la build/deb/

# Fedora/RHEL (RPM)
./scripts/build-rpm.sh
# 检查生成的 RPM 包
ls -la build/rpm/
```

### 安装流程工作流
```bash
# 完整用户安装流程
make user-install                    # 安装到用户目录
make install-systemd                 # 安装 systemd 服务和 udev 规则
make install-desktop                 # 安装桌面文件和菜单项

# 验证安装
which BS2PRO-Controller
ls ~/.local/bin/
ls ~/.config/systemd/user/
ls /etc/udev/rules.d/
```

## 调试和故障排除工作流

### 设备连接问题排查
```bash
# 1. 检查 USB 设备状态
lsusb -v | grep -A5 -B5 "3521:0102"
dmesg | tail -20
journalctl -k --grep="hid"

# 2. 检查权限
ls -la /dev/hidraw*
getfacl /dev/hidraw0

# 3. 直接测试 HID 连接
sudo ./test/hid_test
python3 test/debug_hid.py
```

### 温度监控问题排查
```bash
# 1. 检查系统温度传感器
sensors
find /sys/class/hwmon -name "temp*_input" | head -5
cat $(find /sys/class/hwmon -name "temp*_input" | head -1)

# 2. 检查 NVIDIA GPU 温度
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader

# 3. 测试温度桥接
./build/bin/BS2PRO-Core --test-temperature
```

### 服务启动问题排查
```bash
# 1. 检查 systemd 状态
systemctl --user status bs2pro-controller --no-pager
systemctl --user show bs2pro-controller

# 2. 详细日志
journalctl --user -u bs2pro-controller -f -n 100
journalctl --user -u bs2pro-controller --since "1 hour ago"

# 3. 手动启动调试
cd build/bin
./BS2PRO-Core --debug --log-level=debug
```

### IPC 通信问题排查
```bash
# 1. 检查 Unix 域套接字
ls -la /tmp/bs2pro-*.sock
netstat -lx | grep bs2pro

# 2. IPC 通信测试
./test/ipc_test
python3 test/test_ipc.py
```

## 部署工作流

### 生产环境部署
```bash
# 1. 构建生产版本
make release

# 2. 创建安装包
make package

# 3. 安装验证
sudo make install

# 4. 服务启动和验证
sudo systemctl enable bs2pro-controller
sudo systemctl start bs2pro-controller
sudo systemctl status bs2pro-controller
```

### 用户环境部署
```bash
# 1. 下载预构建包
curl -L https://github.com/KKTIME2024/BS2PRO-Controller-Linux/releases/latest/download/bs2pro-controller-linux-amd64.tar.gz | tar xz
cd bs2pro-controller-linux-amd64

# 2. 运行安装脚本
./install.sh --user

# 3. 配置系统集成
./install-systemd.sh

# 4. 启动应用
BS2PRO-Controller
```

## 维护工作流

### 更新依赖
```bash
# 更新 Go 依赖
go get -u ./...
go mod tidy

# 更新前端依赖
cd frontend
bun update
bun install
cd ..

# 更新系统依赖 (Arch)
sudo pacman -Syu
sudo pacman -S base-devel libudev libusb lm_sensors nvidia-utils
```

### 清理和重置
```bash
# 完整清理
make clean-all

# 重置配置文件
rm -rf ~/.config/bs2pro-controller

# 重置系统集成
make uninstall-systemd
make user-uninstall

# 清除编译缓存
go clean -cache
rm -rf frontend/.next
```

### 性能优化
```bash
# 性能分析构建
make build-profile

# 内存分析
go tool pprof ./build/bin/BS2PRO-Core

# CPU 性能测试
./build/bin/BS2PRO-Core --cpu-profile=cpu.prof
```

## 安全检查工作流

### 权限验证
```bash
# 检查文件权限
find build/bin -type f -exec ls -la {} \;
find /etc/udev/rules.d -name "*bs2pro*" -exec ls -la {} \;

# 检查服务安全配置
systemctl --user show bs2pro-controller | grep -i "protect"

# SELinux/AppArmor 检查 (如适用)
sudo aa-status
getenforce
```

### 代码安全检查
```bash
# Go 安全扫描
go vet ./...
gosec ./...

# 前端安全扫描
cd frontend
bun audit
npm audit
cd ..
```

## 文档生成工作流

### 生成 API 文档
```bash
# 生成 Go 文档
godoc -http=:6060

# 生成前端 TypeScript 文档
cd frontend
bun typedoc --out docs/api
cd ..
```

### 构建文档网站
```bash
# 生成用户手册
make docs

# 构建技术文档
make technical-docs
```

## 发布工作流

### 新版本发布
```bash
# 1. 更新版本号
vi wails.json  # 修改 info.productVersion

# 2. 提交版本更新
git add wails.json
git commit -m "Release v1.2.3"

# 3. 添加版本标签
git tag v1.2.3

# 4. 推送标签
git push origin main --tags

# 5. 构建发布包
make release-all

# 6. 创建 GitHub Release
gh release create v1.2.3 build/release/* --title "v1.2.3" --notes "Release notes..."
```

### 持续集成检查
```bash
# 运行完整测试套件
make test-all

# 检查构建兼容性
make cross-build

# 验证安装脚本
make test-install
```

## 应急恢复工作流

### 恢复损坏的系统配置
```bash
# 1. 停止相关服务
systemctl --user stop bs2pro-controller
sudo rm -f /tmp/bs2pro-*.sock

# 2. 重新安装系统配置
make uninstall-systemd
make install-systemd

# 3. 重新加载配置
sudo udevadm control --reload-rules
sudo udevadm trigger
systemctl --user daemon-reload

# 4. 恢复默认配置
rm -f ~/.config/bs2pro-controller/config.json
./build/bin/BS2PRO-Controller --reset-config

# 5. 重新启动
systemctl --user start bs2pro-controller
```

### 回滚到前一版本
```bash
# 1. 查找前一版本
git tag -l | sort -V | tail -2

# 2. 切换版本
git checkout v1.2.2

# 3. 重新构建
make clean
make build

# 4. 重新安装
make uninstall-systemd
make install-systemd
```

## 监控和日志工作流

### 实时监控
```bash
# 进程监控
htop -p $(pidof BS2PRO-Controller) $(pidof BS2PRO-Core)

# 温度监控
watch -n 1 "cat /sys/class/thermal/thermal_zone*/temp"

# 日志跟踪
tail -f build/bin/logs/core_$(date +%Y%m%d).log
tail -f build/bin/logs/gui_$(date +%Y%m%d).log

# 系统日志监控
journalctl --user -u bs2pro-controller -f
journalctl -k --grep="hid" -f
```

## 注意事项
1. **权限管理**: 所有 HID 设备访问需要正确配置 udev 规则
2. **系统集成**: systemd 用户服务需要在图形会话中启用
3. **温度监控**: 可能需要额外配置 lm-sensors 或 NVIDIA 驱动
4. **网络隔离**: 应用不需要网络访问，但可能需要本地 IPC
5. **资源限制**: 核心服务运行时需要持续访问 USB 设备

*最后更新: 2026-04-26*