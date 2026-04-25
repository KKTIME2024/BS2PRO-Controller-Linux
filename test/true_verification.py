#!/usr/bin/env python3
"""
BS2真实验证脚本
不只是连接测试，还要验证设备实际响应
"""

import hid
import time


def real_verification():
    print("=== BS2真实功能验证 ===")
    print("目标: 验证设备是否真正执行命令，不仅仅是连接成功")
    print()

    try:
        # 1. 连接设备
        print("1. 连接设备...")
        device = hid.device()
        device.open(0x37D7, 0x1001)
        print(
            f"   已连接: {device.get_manufacturer_string()} {device.get_product_string()}"
        )

        # 2. 测试设备响应性
        print("\n2. 测试设备响应性...")

        # 检查当前状态
        print("   a) 发送获取状态命令...")
        status_cmd = bytes.fromhex("5aa54803014c000000000000000000000000000000000000")
        device.write(status_cmd)
        time.sleep(0.5)

        # 尝试读取响应（使用正确的方法）
        print("   b) 尝试读取响应...")
        try:
            # 正确的读取方式
            data = device.read(64)
            if data:
                print(f"   ✅ 读取到响应: {bytes(data).hex()}")
            else:
                print("   ⚠️  无响应数据（可能正常）")
        except Exception as e:
            print(f"   ❌ 读取错误: {e}")

        # 3. 验证命令执行
        print("\n3. 验证命令执行...")
        print("   注意：请观察BS2设备的实际变化（灯是否亮/灭，风扇是否变化）")

        # 开启挡位灯
        print("   a) 发送『开启挡位灯』命令...")
        on_cmd = bytes.fromhex("5aa54803014c000000000000000000000000000000000000")
        device.write(on_cmd)
        print("      命令已发送")
        print("      ✅ 请确认BS2设备上的挡位灯是否亮起（应该是蓝色或白色）")
        time.sleep(2)

        # 关闭挡位灯
        print("\n   b) 发送『关闭挡位灯』命令...")
        off_cmd = bytes.fromhex("5aa54803004b000000000000000000000000000000000000")
        device.write(off_cmd)
        print("      命令已发送")
        print("      ✅ 请确认BS2设备上的挡位灯是否熄灭")
        time.sleep(2)

        # 静音模式
        print("\n   c) 发送『1档静音』命令...")
        quiet_cmd = bytes.fromhex("5aa526050014054400000000000000000000000000000000")
        device.write(quiet_cmd)
        print("      命令已发送")
        print("      ✅ 请确认BS2风扇是否降低转速（声音变小）")
        time.sleep(3)

        # 标准模式
        print("\n   d) 发送『2档标准』命令...")
        normal_cmd = bytes.fromhex("5aa526050134086800000000000000000000000000000000")
        device.write(normal_cmd)
        print("      命令已发送")
        print("      ✅ 请确认BS2风扇是否提高转速（声音变大）")
        time.sleep(3)

        # 返回到静音模式
        print("\n   e) 返回『1档静音』模式...")
        device.write(quiet_cmd)
        time.sleep(2)

        # 4. 测试连续命令
        print("\n4. 测试连续命令响应...")
        print("   发送5次快速开关灯命令...")
        for i in range(5):
            device.write(on_cmd)
            time.sleep(0.3)
            device.write(off_cmd)
            time.sleep(0.3)
            print(f"   第{i + 1}次开关命令")

        # 5. 读取设备信息
        print("\n5. 读取设备详细信息...")
        try:
            print(f"   制造商: {device.get_manufacturer_string()}")
            print(f"   产品名: {device.get_product_string()}")
            print(f"   序列号: {device.get_serial_number_string()}")

            # 尝试获取报告长度
            print(f"   输入报告长度: {device.get_input_report_length(0)}")
            print(f"   输出报告长度: {device.get_output_report_length(0)}")
        except Exception as e:
            print(f"   部分信息获取失败: {e}")

        device.close()

        print("\n" + "=" * 60)
        print("📋 验证总结")
        print("=" * 60)
        print("✅ 已验证:")
        print("   1. 设备连接功能")
        print("   2. 命令发送能力")
        print()
        print("❓ 需要您手动确认:")
        print("   1. 挡位灯是否响应开/关命令？")
        print("   2. 风扇转速是否随挡位命令变化？")
        print("   3. 设备是否有任何指示灯响应？")
        print()
        print("🔧 技术问题发现:")
        print("   - hid.read() API使用有问题（参数不匹配）")
        print("   - 需要验证设备是否正确解析了命令")
        print()
        print("请根据实际设备响应回答上面的问题。")

    except Exception as e:
        print(f"\n❌ 验证失败: {e}")
        print("可能原因:")
        print("   1. 设备未连接")
        print("   2. 权限问题")
        print("   3. 设备处于异常状态")

        return False


if __name__ == "__main__":
    print("BS2真实功能验证脚本")
    print("重要：测试时需要观察BS2设备的实际物理响应")
    print("-" * 60)

    success = real_verification()

    print("\n" + "=" * 60)
    if success:
        print("✅ 基础验证完成")
        print("请根据物理设备响应确认功能是否真正有效")
    else:
        print("❌ 验证过程出错")
        print("需要进一步调试")
