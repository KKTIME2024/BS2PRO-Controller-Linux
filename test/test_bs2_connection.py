#!/usr/bin/env python3
"""
BS2硬件连接测试脚本
直接测试与BS2设备的连接
"""

import sys
import os
import time


def test_bs2_connection():
    print("=== BS2硬件连接测试 ===")
    print(f"Python版本: {sys.version}")

    try:
        import hid

        print("✅ hid模块加载成功")
    except ImportError as e:
        print(f"❌ hid模块导入失败: {e}")
        print("请安装: pip install hidapi 或 sudo pacman -S python-hidapi")
        return False

    # 检查设备是否存在
    device_path = "/dev/hidraw7"
    if not os.path.exists(device_path):
        print(f"❌ 设备路径不存在: {device_path}")
        print("请确保BS2设备已连接并开机")
        return False

    # 检查权限
    try:
        import stat

        mode = os.stat(device_path).st_mode
        print(f"设备权限: {oct(mode)[-3:]}")
        if mode & stat.S_IROTH and mode & stat.S_IWOTH:
            print("✅ 设备有读写权限")
        else:
            print("❌ 设备权限不足，需要666权限")
            print("  请运行:")
            print("  sudo chmod 666 /dev/hidraw7")
    except Exception as e:
        print(f"权限检查错误: {e}")

    # 尝试连接设备
    print("\n尝试连接BS2设备 (0x37D7:0x1001)...")

    try:
        # 方法1: 使用已知的vendor/product ID
        device = hid.device()
        device.open(0x37D7, 0x1001)
        print("✅ 设备连接成功!")

        # 获取设备信息
        print(f"\n设备信息:")
        print(f"  制造商: {device.get_manufacturer_string()}")
        print(f"  产品名: {device.get_product_string()}")
        print(f"  序列号: {device.get_serial_number_string()}")

        # 测试命令：开启挡位灯
        print("\n发送测试命令: 开启挡位灯")
        cmd_bytes = bytes.fromhex("5aa54803014c000000000000000000000000000000000000")

        try:
            result = device.write(cmd_bytes)
            print(f"  写入 {result} 字节")

            # 等待响应
            time.sleep(0.5)

            # 尝试读取
            print("  尝试读取设备响应...")
            data = device.read(64, timeout=1000)
            if data:
                hex_data = bytes(data).hex()
                print(
                    f"  读取成功: {hex_data[:80]}{'...' if len(hex_data) > 80 else ''}"
                )

                # 解析数据包
                if hex_data.startswith("5aa5"):
                    print("  ✅ 数据包格式正确 (以5AA5开头)")

                    # 简单解析
                    if len(data) >= 8:
                        cmd = data[2] if len(data) > 2 else 0
                        status = data[3] if len(data) > 3 else 0
                        print(f"  命令: 0x{cmd:02X}, 状态: 0x{status:02X}")
                else:
                    print("  ⚠️  数据包格式不标准")
            else:
                print("  ⚠️  无响应数据（可能是正常现象）")

        except Exception as e:
            print(f"  通信错误: {e}")

        # 测试命令：关闭挡位灯
        print("\n发送测试命令: 关闭挡位灯")
        cmd_bytes = bytes.fromhex("5aa54803004b000000000000000000000000000000000000")
        try:
            result = device.write(cmd_bytes)
            print(f"  写入 {result} 字节")
            time.sleep(0.5)
        except Exception as e:
            print(f"  写入错误: {e}")

        # 读取设备状态
        print("\n读取设备当前状态...")
        try:
            for i in range(3):
                data = device.read(64, timeout=500)
                if data:
                    hex_data = bytes(data).hex()
                    print(
                        f"  状态 {i + 1}: {hex_data[:80]}{'...' if len(hex_data) > 80 else ''}"
                    )
                else:
                    print(f"  状态 {i + 1}: 无数据")
                time.sleep(0.2)
        except Exception as e:
            print(f"  状态读取错误: {e}")

        device.close()
        print("\n✅ 设备连接测试完成")
        return True

    except Exception as e:
        print(f"❌ 连接失败: {e}")
        print("\n建议的调试步骤:")
        print("1. 检查设备权限: ls -la /dev/hidraw7")
        print("2. 重新加载udev规则:")
        print("   sudo udevadm control --reload-rules")
        print("   sudo udevadm trigger")
        print("3. 临时修复权限: sudo chmod 666 /dev/hidraw7")
        print("4. 验证设备状态: lsusb | grep 37d7")
        return False


def main():
    print("BS2硬件连接测试")
    print("=" * 50)

    success = test_bs2_connection()

    print("\n" + "=" * 50)
    if success:
        print("✅ 测试成功! BS2设备连接正常，基本功能可用")
        print("   可以继续运行 python scripts/hid_controller.py 进行高级测试")
        print("\n下一步建议:")
        print("1. 使用 hid_controller.py 进行完整功能测试")
        print("2. 测试风扇旋转控制")
        print("3. 测试温度跟随功能")
    else:
        print("❌ 测试失败，请检查权限和设备连接")
        print("\n检查清单:")
        print("1. ✅ 设备识别: lsusb | grep 37d7")
        print("2. ❌ 用户权限: sudo chmod 666 /dev/hidraw7")
        print(
            "3. 🔄 udev规则: sudo udevadm control --reload-rules && sudo udevadm trigger"
        )
        print("4. 👥 用户组: sudo usermod -aG plugdev $USER && 重新登录")


if __name__ == "__main__":
    main()
