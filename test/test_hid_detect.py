#!/usr/bin/env python3
"""
BS2PRO HID设备检测脚本
用于检测系统是否能够识别BS2/HID设备
"""

import os
import sys
import time


def test_hid_api():
    """测试HID API可用性"""
    print("=== HID设备检测测试 ===")

    # 第一步：检查系统接口
    print("\n1. 系统HID接口检查:")

    # 检查/dev/hidraw设备
    hidraw_count = 0
    try:
        hidraw_paths = []
        for entry in os.listdir("/dev"):
            if entry.startswith("hidraw"):
                hidraw_count += 1
                hidraw_paths.append(f"/dev/{entry}")
        print(f"  找到 {hidraw_count} 个hidraw设备")
        for path in hidraw_paths[:3]:  # 只显示前3个
            perms = oct(os.stat(path).st_mode)[-3:]
            print(f"    {path}: 权限 {perms}")
        if hidraw_count > 3:
            print(f"    ... 还有 {hidraw_count - 3} 个设备")
    except Exception as e:
        print(f"   错误: {e}")

    # 检查udev规则文件
    print("\n2. udev规则检查:")
    udev_rule = "/etc/udev/rules.d/99-bs2pro-controller.rules"
    if os.path.exists(udev_rule):
        print(f"  找到udev规则: {udev_rule}")
        try:
            with open(udev_rule, "r") as f:
                content = f.read()
                print("  规则内容:")
                for line in content.strip().split("\n"):
                    if line and not line.startswith("#"):
                        print(f"    {line}")
        except Exception as e:
            print(f"   读取错误: {e}")
    else:
        print(f"  未找到udev规则: {udev_rule}")

    # 检查HID枚举（如果hid模块可用）
    print("\n3. 尝试HID枚举:")
    try:
        # 尝试动态导入hid模块
        import hid

        print("  hid模块加载成功")

        print("  枚举所有HID设备:")
        devices_found = 0
        for device_info in hid.enumerate():
            devices_found += 1
            vendor_id = device_info.get("vendor_id", 0)
            product_id = device_info.get("product_id", 0)
            manufacturer = device_info.get("manufacturer_string", "")
            product_name = device_info.get("product_string", "")

            # 检查是否是BS2设备 (0x37D7 vendor ID)
            if vendor_id == 0x37D7:
                print(f"  ⚡️ 找到BS2设备!")
                print(f"    厂商ID: 0x{vendor_id:04X}")
                print(f"    产品ID: 0x{product_id:04X}")
                print(f"    制造商: {manufacturer}")
                print(f"    产品名: {product_name}")
                print(f"    路径: {device_info.get('path', '未知')}")
                print(f"    使用计数: {device_info.get('usage_page', '未知')}")
            elif vendor_id > 0:
                # 显示其他有意义的设备
                if manufacturer or product_name:
                    print(f"    设备: {manufacturer} {product_name}")

        print(f"  总共找到 {devices_found} 个HID设备")

    except ImportError:
        print("  ❌ hid模块未安装")
        print("  请安装: pip install hidapi 或 sudo pacman -S python-hidapi")
    except Exception as e:
        print(f"  ❌ HID枚举错误: {e}")

    # 检查BS2可能的产品ID
    print("\n4. BS2设备搜索:")
    bs2_vendor_id = 0x37D7  # 飞智
    bs2_product_ids = {0x1001: "BS2", 0x1002: "BS2PRO"}

    try:
        import hid

        for device_info in hid.enumerate():
            vendor_id = device_info.get("vendor_id", 0)
            if vendor_id == bs2_vendor_id:
                product_id = device_info.get("product_id", 0)
                device_name = bs2_product_ids.get(
                    product_id, f"未知(0x{product_id:04X})"
                )
                print(f"  ✅ 找到 {device_name} 设备:")
                print(f"     厂商ID: 0x{vendor_id:04X}")
                print(f"     产品ID: 0x{product_id:04X} ({device_name})")
                print(f"     路径: {device_info.get('path', '未知')}")

                # 尝试打开设备
                try:
                    device = hid.device()
                    device.open(vendor_id, product_id)
                    print(f"     连接状态: 成功")
                    device.close()
                    return True
                except Exception as e:
                    print(f"     连接失败: {e}")
                    return False
    except ImportError:
        print("  hid模块未安装，跳过详细检测")
    except Exception as e:
        print(f"  搜索错误: {e}")

    print("\n5. 建议:")
    print("  - 确保BS2设备已开机并连接到电脑")
    print("  - 运行 sudo udevadm control --reload-rules && sudo udevadm trigger")
    print("  - 安装hid模块: pip install hidapi")
    print("  - 检查设备权限: ls -la /dev/hidraw*")
    print("  - 查看连接: lsusb")

    return False


def check_usb_connection():
    """检查是否有疑似BS2的USB设备"""
    print("\n=== USB设备检查 ===")

    # 检查lsusb命令
    try:
        import subprocess

        result = subprocess.run(["which", "lsusb"], capture_output=True, text=True)
        if result.returncode != 0:
            print("  ❌ lsusb命令不可用")
            return

        lsusb_output = subprocess.run(["lsusb"], capture_output=True, text=True)

        found = False
        for line in lsusb_output.stdout.split("\n"):
            line_lower = line.lower()
            # 搜索相关关键词
            keywords = ["37d7", "flydigi", "bs2", "fly", "controller"]
            for keyword in keywords:
                if keyword in line_lower:
                    print(f"  🔍 发现相关设备: {line.strip()}")
                    found = True
                    break

        if not found:
            print("  ℹ️ 未发现疑似BS2的USB设备")
            print("    提示: 请确保BS2已开机并连接到电脑USB口")
    except Exception as e:
        print(f"  ❌ USB检查错误: {e}")


def main():
    print("BS2PRO硬件连接测试脚本")
    print("=" * 50)

    # 检查系统状态
    try:
        with open("/proc/version", "r") as f:
            kernel_version = f.read().strip()
            print(
                f"Kernel: {kernel_version.split(' ')[2] if ' ' in kernel_version else kernel_version}"
            )
    except:
        pass

    # 运行测试
    hid_detected = test_hid_api()
    check_usb_connection()

    print("\n" + "=" * 50)
    if hid_detected:
        print("✅ HID设备检测成功！")
        print("   可以继续运行 python scripts/hid_controller.py 进行完整测试")
    else:
        print("❌ 未检测到BS2 HID设备")
        print("   请检查设备连接、权限设置和依赖安装")

    print("\n下一步建议:")
    print("1. 将BS2设备连接到电脑USB口并确保开机")
    print("2. 运行: lsusb | grep -i flydigi 检查设备识别")
    print(
        "3. 配置udev规则 (sudo cp build/99-bs2pro-controller.rules /etc/udev/rules.d/)"
    )
    print(
        "4. 重新加载udev规则: sudo udevadm control --reload-rules && sudo udevadm trigger"
    )
    print("5. 注销并重新登录以应用组权限")


if __name__ == "__main__":
    main()
