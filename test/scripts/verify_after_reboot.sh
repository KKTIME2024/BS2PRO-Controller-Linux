#!/bin/bash

echo "========================================"
echo "      重启后BS2设备验证脚本"
echo "========================================"

echo ""
echo "1. 验证设备连接:"
if lsusb | grep -q "37d7"; then
    echo "✅ BS2设备已连接"
    lsusb | grep "37d7"
else
    echo "❌ 未检测到BS2设备"
    echo "请确保设备已连接到电脑并开机"
    exit 1
fi

echo ""
echo "2. 验证设备权限:"
HID_DEVICE=$(ls /dev/hidraw* 2>/dev/null | xargs -I{} sh -c 'echo {} $(ls -la {} | cut -d" " -f1)' | grep "crw.rw.rw" | head -1 | cut -d" " -f1)
if [ -n "$HID_DEVICE" ]; then
    echo "✅ 找到正确权限的HID设备: $HID_DEVICE"
    ls -la $HID_DEVICE
else
    echo "❌ 未找到正确权限的HID设备"
    echo "可能需要重新加载udev规则:"
    echo "  sudo udevadm control --reload-rules"
    echo "  sudo udevadm trigger"
    echo "或临时修复:"
    echo "  sudo chmod 666 /dev/hidraw*"
fi

echo ""
echo "3. 运行快速测试:"
python3 test_bs2_connection.py 2>&1 | grep -E "(✅|❌|===|设备)" | head -20

echo ""
echo "4. 可选：运行完整测试:"
echo "   python3 auto_test_bs2.py"
echo "   python3 scripts/hid_controller.py"

echo ""
echo "========================================"
echo "验证完成"
echo ""
echo "如果测试失败，请检查:"
echo "1. 设备连接状态"
echo "2. udev规则配置"
echo "3. 用户组权限"
echo "4. Python依赖 (hidapi)"
echo "========================================"

# 可选：自动运行完整测试
read -p "是否运行完整测试？(y/N): " -n 1 choice
echo ""
if [[ $choice =~ ^[Yy]$ ]]; then
    echo "运行完整测试..."
    python3 auto_test_bs2.py
fi