#!/usr/bin/env python3
"""
诊断脚本: 测试 BS2 控制命令是否需要 Report ID (0x02) 前缀。

用于排查 Linux hidraw 上 Write() 返回成功但硬件无响应的问题。
"""

import sys
import time
import os


def check_hid_perms(path):
    """检查 hidraw 设备权限"""
    try:
        mode = os.stat(path).st_mode
        perms = oct(mode)[-3:]
        return perms
    except:
        return "???"


def find_bs2_device():
    """查找 BS2 设备"""
    import hid
    for info in hid.enumerate():
        if info.get("vendor_id") == 0x37D7:
            return info
    return None


def test_write(device, cmd_bytes, description):
    """发送命令并检查返回"""
    print(f"\n  [{description}]")
    hex_str = " ".join(f"{b:02x}" for b in cmd_bytes)
    print(f"  发送 ({len(cmd_bytes)} bytes): {hex_str}")
    try:
        result = device.write(cmd_bytes)
        print(f"  write() 返回: {result}")
        return result >= 0
    except Exception as e:
        print(f"  write() 异常: {e}")
        return False


def read_response(device, timeout_ms=2000):
    """尝试读取设备响应"""
    try:
        data = device.read(64, timeout=timeout_ms)
        if data:
            hex_str = " ".join(f"{b:02x}" for b in data)
            print(f"  读取 ({len(data)} bytes): {hex_str}")
            return data
        else:
            print("  无响应数据")
            return None
    except Exception as e:
        print(f"  读取错误: {e}")
        return None


def main():
    print("=" * 60)
    print("BS2 HID 命令 Report ID 诊断")
    print("=" * 60)

    try:
        import hid
    except ImportError:
        print("请安装: pip install hidapi")
        return 1

    # 查找设备
    dev_info = find_bs2_device()
    if not dev_info:
        print("未找到 BS2 设备 (VID=0x37D7)")
        print("请确认设备已连接并开机")
        return 1

    path = dev_info.get("path", "")
    pid = dev_info.get("product_id", 0)
    name = "BS2PRO" if pid == 0x1002 else "BS2" if pid == 0x1001 else f"0x{pid:04X}"
    print(f"\n设备: {name} (PID=0x{pid:04X})")
    print(f"路径: {path}")
    print(f"权限: {check_hid_perms(path)}")

    # 连接设备
    try:
        device = hid.device()
        device.open(0x37D7, 0x1001)
        print("连接成功")
    except Exception as e:
        print(f"连接失败: {e}")
        return 1

    # 读取基线数据
    print("\n--- 读取基线输入报告 (确认数据通道正常) ---")
    read_response(device)

    # 测试命令: 挡位灯 ON
    # 完整命令: 02 5A A5 48 03 01 4C (补齐到 23 bytes)
    cmd_body = bytes.fromhex("5aa54803014c")
    # 补齐到 23 bytes
    cmd_padded = cmd_body + b"\x00" * (23 - len(cmd_body))
    cmd_with_report_id = b"\x02" + cmd_padded[:-1]  # 保持总长度 23

    print("\n=== 测试 1: 带 Report ID (0x02) 前缀 ===")
    print("  (Go 代码当前使用此格式)")
    test_write(device, cmd_with_report_id, "挡位灯 ON (WITH 0x02)")
    time.sleep(0.5)
    read_response(device, 500)

    print("\n=== 测试 2: 不带 Report ID 前缀 ===")
    print("  (Python 原始测试脚本使用此格式)")
    test_write(device, cmd_padded, "挡位灯 ON (WITHOUT 0x02)")
    time.sleep(0.5)
    read_response(device, 500)

    # 测试 3: 使用 SendFeatureReport (控制端点)
    print("\n=== 测试 3: SendFeatureReport (控制端点) ===")
    print("  (测试是否应该用控制端点而非中断端点)")
    try:
        test_write(device, cmd_with_report_id, "挡位灯 ON via send_feature_report (WITH 0x02)")
        # Note: Python hidapi sends via hid_send_feature_report when using device.send_feature_report()
        result = device.send_feature_report(cmd_with_report_id)
        print(f"  send_feature_report 返回: {result}")
    except Exception as e:
        print(f"  send_feature_report 异常: {e}")

    time.sleep(0.5)
    read_response(device, 500)

    # 测试 4: 不带 Report ID 的 send_feature_report
    print("\n=== 测试 4: SendFeatureReport 不带 Report ID ===")
    try:
        result = device.send_feature_report(cmd_padded)
        print(f"  send_feature_report 返回: {result}")
    except Exception as e:
        print(f"  send_feature_report 异常: {e}")

    time.sleep(0.5)
    read_response(device, 500)

    # 测试 5: 风扇转速命令 (0x21)
    print("\n=== 测试 5: 设置风扇转速 ===")
    # 进入实时转速模式 + 设置转速 2000 RPM
    # 进入模式: 02 5A A5 23 02 25 00
    enter_mode = bytes.fromhex("5aa523022500") + b"\x00" * 16  # 补齐到 23
    # 设置 2000 RPM: 02 5A A5 21 04 d0 07 d9
    # rpm 2000 = 0x07d0 = d0 07 (little endian)
    # checksum = (5a+a5+21+04+d0+07+1) & 0xff = (90+165+33+4+208+7+1) & 0xff = 508 & 0xff = 0xFC
    set_rpm = bytes.fromhex("5aa52104d007fc") + b"\x00" * 16

    # Without Report ID
    print("\n  --- 不带 Report ID ---")
    test_write(device, enter_mode, "进入实时转速模式")
    time.sleep(0.1)
    test_write(device, set_rpm, "设置 2000 RPM")
    time.sleep(0.5)
    read_response(device, 500)

    # With Report ID
    print("\n  --- 带 Report ID (0x02) ---")
    enter_mode_02 = b"\x02" + enter_mode[:-1]
    set_rpm_02 = b"\x02" + set_rpm[:-1]
    test_write(device, enter_mode_02, "进入实时转速模式")
    time.sleep(0.1)
    test_write(device, set_rpm_02, "设置 2000 RPM")
    time.sleep(0.5)
    read_response(device, 500)

    # Final read
    print("\n--- 最终输入报告 (观察 status/gear 字段变化) ---")
    for i in range(3):
        data = read_response(device, 500)
        time.sleep(0.2)

    device.close()
    print("\n" + "=" * 60)
    print("诊断完成。请观察: 挡位灯是否亮起? 风扇转速是否变化?")
    print("=" * 60)


if __name__ == "__main__":
    sys.exit(main())
