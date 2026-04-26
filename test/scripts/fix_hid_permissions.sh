#!/bin/bash
echo "===== 修复HID设备权限脚本 ====="
echo ""
echo "当前HID设备权限:"
ls -la /dev/hidraw* 2>/dev/null || echo "未找到hidraw设备"
echo ""
echo "用户组信息:"
id
echo ""
echo "1. 重新加载udev规则（需要sudo密码）"
read -p "请输入sudo密码: " -s password
echo ""
echo -n $password | sudo -S udevadm control --reload-rules 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ udev规则重新加载成功"
else
    echo "❌ 重新加载失败"
fi

echo ""
echo "2. 触发udev事件"
echo -n $password | sudo -S udevadm trigger 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ udev事件触发成功"
else
    echo "❌ 触发失败"
fi

echo ""
echo "3. 查看更新后的权限"
sleep 2
ls -la /dev/hidraw* 2>/dev/null || echo "未找到hidraw设备"

echo ""
echo "4. 测试设备连接"
python3 -c "
import sys
sys.path.append('.')
try:
    import hid
    device = hid.device()
    device.open(0x37d7, 0x1001)
    print('✅ 设备连接成功!')
    
    # 尝试发送简单命令
    print('发送测试命令...')
    test_cmd = bytes.fromhex('5aa54803014c000000000000000000000000000000000000')
    result = device.write(test_cmd)
    print(f'写入结果: {result} 字节')
    
    # 尝试读取
    print('尝试读取...')
    try:
        data = device.read(64, timeout=1000)
        if data:
            print(f'读取到数据: {data.hex()}')
        else:
            print('读取超时或无数据')
    except Exception as e:
        print(f'读取错误: {e}')
    
    device.close()
    
except Exception as e:
    print(f'❌ 连接失败: {e}')
"

echo ""
echo "===== 脚本执行完成 ====="
echo "如果仍然有权限问题，请尝试:"
echo "1. 注销并重新登录"
echo "2. 或者重启电脑"
echo "3. 检查用户是否在plugdev组: groups \$USER"