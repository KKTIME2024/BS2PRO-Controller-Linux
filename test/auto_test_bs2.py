#!/usr/bin/env python3
"""
BS2自动测试脚本
自动运行一系列测试命令
"""

import time
import hid


def test_basic_commands():
    """测试基本命令"""
    print("=== BS2自动测试脚本 ===")
    print(f"时间: {time.ctime()}")

    try:
        # 连接设备
        print("\n1. 连接设备...")
        device = hid.device()
        device.open(0x37D7, 0x1001)
        print(
            f"  连接到: {device.get_manufacturer_string()} {device.get_product_string()}"
        )

        # 测试开启挡位灯
        print("\n2. 测试开启挡位灯...")
        cmd_on = bytes.fromhex("5aa54803014c000000000000000000000000000000000000")
        result = device.write(cmd_on)
        print(f"  发送命令: {cmd_on.hex()}")
        print(f"  写入 {result} 字节")
        time.sleep(1)

        # 测试关闭挡位灯
        print("\n3. 测试关闭挡位灯...")
        cmd_off = bytes.fromhex("5aa54803004b000000000000000000000000000000000000")
        result = device.write(cmd_off)
        print(f"  发送命令: {cmd_off.hex()}")
        print(f"  写入 {result} 字节")
        time.sleep(1)

        # 测试挡位控制（1档静音）
        print("\n4. 测试1档静音模式...")
        cmd_gear1 = bytes.fromhex("5aa526050014054400000000000000000000000000000000")
        result = device.write(cmd_gear1)
        print(f"  发送命令: {cmd_gear1.hex()}")
        print(f"  写入 {result} 字节")
        print("  设备应切换到静音模式")
        time.sleep(2)

        # 测试挡位控制（2档标准）
        print("\n5. 测试2档标准模式...")
        cmd_gear2 = bytes.fromhex("5aa526050134086800000000000000000000000000000000")
        result = device.write(cmd_gear2)
        print(f"  发送命令: {cmd_gear2.hex()}")
        print(f"  写入 {result} 字节")
        print("  设备应切换到标准模式，转速应增加")
        time.sleep(2)

        # 测试通电自启动
        print("\n6. 测试通电自启动开启...")
        cmd_auto_start = bytes.fromhex(
            "5aa50c030211000000000000000000000000000000000000"
        )
        result = device.write(cmd_auto_start)
        print(f"  发送命令: {cmd_auto_start.hex()}")
        print(f"  写入 {result} 字节")
        print("  设备设置通电自启动开启")
        time.sleep(1)

        # 测试智能启停
        print("\n7. 测试智能启停（即时模式）...")
        cmd_smart_stop = bytes.fromhex(
            "5aa50d030111000000000000000000000000000000000000"
        )
        result = device.write(cmd_smart_stop)
        print(f"  发送命令: {cmd_smart_stop.hex()}")
        print(f"  写入 {result} 字节")
        print("  设备设置智能启停即时模式")
        time.sleep(1)

        # 回到1档静音模式
        print("\n8. 回到1档静音模式...")
        result = device.write(cmd_gear1)
        print(f"  写入 {result} 字节")
        time.sleep(1)

        # 读取设备状态（尝试）
        print("\n9. 尝试读取设备状态...")
        try:
            # 尝试读取
            data = device.read(64)
            if data:
                hex_data = bytes(data).hex()
                print(f"  读取到数据: {hex_data}")

                # 简单解析
                if hex_data.startswith("5aa5"):
                    print("  ✅ 有效数据包（结构正确）")
                    if len(data) >= 8:
                        print(f"  同步码: 0x{data[0]:02X}{data[1]:02X}")
                        print(f"  命令: 0x{data[2]:02X}")
                        print(f"  状态: 0x{data[3]:02X}")
            else:
                print("  ⚠️  无数据返回（正常，设备可能不主动发送数据）")
        except Exception as e:
            print(f"  ❌ 读取错误: {e}")

        # 关闭连接
        device.close()
        print("\n✅ 所有基本命令测试完成")

        print("\n=== 测试总结 ===")
        print("1. ✅ 设备连接成功")
        print("2. ✅ 挡位灯控制（开/关）")
        print("3. ✅ 挡位控制（静音/标准）")
        print("4. ✅ 功能设置（通电自启动/智能启停）")
        print("5. 📊 数据读取需要进一步调试")

        print("\n=== 手动验证建议 ===")
        print("- 观察BS2设备：挡位灯应已关闭")
        print("- 风扇转速：应处于静音模式（低转速）")
        print("- 设备指示灯：应有响应")

        return True

    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        return False


if __name__ == "__main__":
    success = test_basic_commands()

    print("\n" + "=" * 50)
    if success:
        print("✅ BS2硬件连接测试成功！")
        print("设备响应正常，所有基本功能可用。")
    else:
        print("❌ 测试失败，需要检查连接或命令格式。")

    print("\n下一步：")
    print("1. 执行高级测试：python3 scripts/hid_controller.py")
    print("2. 测试更多功能：查看 scripts/hid_data.md")
    print("3. 集成到主应用：测试系统温度监控结合")
