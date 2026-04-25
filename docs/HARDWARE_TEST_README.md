# BS2硬件连接测试文档

## 当前状态
- ✅ 设备已识别：BS2 (Vendor ID: 0x37D7, Product ID: 0x1001)
- ✅ 系统温度监控：正常
- ✅ HID库支持：正常
- ❌ **权限问题**：`/dev/hidraw7` 权限为600，需要666

## 设备信息
- 设备类型：BS2（不是BS2PRO）
- 路径：`/dev/hidraw7`
- Vendor ID：`0x37D7`
- Product ID：`0x1001`
- USB显示：`Bus 003 Device 017: ID 37d7:1001 Flydigi Flydigi BS2`

## 需要运行的命令（需要sudo权限）

### 1. 修复当前权限（立即生效）
```bash
sudo chmod 666 /dev/hidraw7
```

### 2. 重新加载udev规则（长期生效）
```bash
# 如果已安装udev规则，重新加载
sudo udevadm control --reload-rules
sudo udevadm trigger

# 如果未安装，先安装规则
sudo cp build/99-bs2pro-controller.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### 3. 将用户添加到plugdev组（可选）
```bash
sudo usermod -aG plugdev $USER
# 注意：需要注销并重新登录生效
```

## 测试脚本

### 快速检测脚本
```bash
python3 test_hid_detect.py
```

### 连接测试脚本
```bash
python3 test_bs2_connection.py
```

### 完整功能测试
```bash
python3 scripts/hid_controller.py
```

## 重启后测试流程

1. **连接设备**
   - 确保BS2已开机
   - 连接到电脑USB口

2. **验证设备识别**
   ```bash
   lsusb | grep 37d7
   # 应该显示: Bus XXX Device XXX: ID 37d7:1001 Flydigi Flydigi BS2
   ```

3. **运行测试**
   ```bash
   # 选项A: 快速测试
   python3 test_bs2_connection.py
   
   # 选项B: 交互式测试
   python3 scripts/hid_controller.py
   ```

4. **测试内容**
   - 基础连接测试
   - 挡位灯控制（开/关）
   - 风扇挡位设置
   - 转速控制
   - 设备状态读取

## 常见问题

### 1. 权限问题
```bash
# 检查权限
ls -la /dev/hidraw*

# 临时修复
sudo chmod 666 /dev/hidrawX  # X是设备号

# 验证
python3 test_bs2_connection.py
```

### 2. 设备未识别
```bash
# 重新扫描USB
sudo dmesg | tail -20 | grep -i usb

# 检查内核日志
sudo journalctl -f | grep hid
```

### 3. Python依赖问题
```bash
# 安装hidapi
pip install hidapi

# Arch Linux
sudo pacman -S python-hidapi
```

## 测试命令记录

### 基础命令（来自hid_data.md）
- 开挡位灯：`5aa54803014c000000000000000000000000000000000000`
- 关挡位灯：`5aa54803004b000000000000000000000000000000000000`

### 挡位设置
- 静音档（1档）：`5aa526050014054400000000000000000000000000000000`
- 标准档（2档）：`5aa526050134086800000000000000000000000000000000`

## 联系信息
- 项目：BS2PRO Controller Linux移植版
- 设备：BS2（Flydigi散热器）
- 测试完成度：系统监控正常，等待硬件连接测试
- 最后更新时间：2026-04-25