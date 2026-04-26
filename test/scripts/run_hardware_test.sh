#!/bin/bash

# BS2硬件测试脚本
echo "========================================"
echo "      BS2硬件连接测试脚本"
echo "========================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}步骤1: 检查设备连接状态${NC}"
echo "----------------------------------------"

# 检查设备是否识别
echo "1. 检查USB设备:"
if lsusb | grep -q "37d7"; then
    echo -e "${GREEN}✅ 已识别BS2设备${NC}"
    lsusb | grep "37d7"
else
    echo -e "${RED}❌ 未识别到BS2设备${NC}"
    echo "请确保:"
    echo "  1. BS2设备已连接到电脑USB口"
    echo "  2. BS2设备已开机"
    echo "  3. USB线正常工作"
    exit 1
fi

echo ""
echo "2. 检查HID设备权限:"
HID_DEVICES=$(ls /dev/hidraw* 2>/dev/null | wc -l)
if [ $HID_DEVICES -gt 0 ]; then
    echo -e "${GREEN}✅ 找到 $HID_DEVICES 个HID设备${NC}"
    
    # 找到BS2设备
    for dev in /dev/hidraw*; do
        if [ -e "$dev" ]; then
            perms=$(stat -c "%A" "$dev")
            echo "  $dev: 权限 $perms"
        fi
    done
else
    echo -e "${RED}❌ 未找到HID设备${NC}"
fi

echo ""
echo -e "${YELLOW}步骤2: 运行测试${NC}"
echo "----------------------------------------"

echo "3. 运行设备检测脚本:"
python3 test_hid_detect.py

echo ""
echo "4. 运行连接测试:"
python3 test_bs2_connection.py

echo ""
echo -e "${YELLOW}步骤3: 测试结果汇总${NC}"
echo "----------------------------------------"

echo "5. 系统温度监控:"
sensors | grep -E "Core|Package|temp" | head -5

echo ""
echo "6. 使用建议:"
echo "   - 如连接失败，运行: sudo chmod 666 /dev/hidraw*"
echo "   - 重新加载udev规则: sudo udevadm control --reload-rules"
echo "   - 详细测试: python3 scripts/hid_controller.py"
echo "   - 重启后测试流程见: HARDWARE_TEST_README.md"

echo ""
echo "========================================"
echo -e "${GREEN}测试完成${NC}"
echo "========================================"

echo ""
echo "可选测试:"
echo "  A. 运行完整交互测试:"
echo "     python3 scripts/hid_controller.py"
echo "  B. 测试特定功能:"
echo "     python3 scripts/hid_controller.py --help"
echo "  C. 查看测试文档:"
echo "     cat HARDWARE_TEST_README.md"