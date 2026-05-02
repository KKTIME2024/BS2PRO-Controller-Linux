#!/usr/bin/env python3
"""
获取 BS2 设备 HID Report Descriptor 并重试测试（修复 read API 兼容性）。
"""

import sys
import time
import os

def main():
    try:
        import hid
    except ImportError:
        print("请安装: pip install hidapi")
        return 1

    # Find device
    dev_info = None
    for info in hid.enumerate():
        if info.get("vendor_id") == 0x37D7:
            dev_info = info
            break

    if not dev_info:
        print("未找到 BS2 设备 (VID=0x37D7)")
        return 1

    pid = dev_info.get("product_id", 0)
    path = dev_info.get("path", b"").decode() if isinstance(dev_info.get("path"), bytes) else dev_info.get("path", "")
    name = "BS2PRO" if pid == 0x1002 else "BS2"
    print(f"设备: {name} (PID=0x{pid:04X})  路径: {path}")

    device = hid.device()
    device.open(0x37D7, 0x1001)
    print("连接成功\n")

    # --- Get HID Report Descriptor ---
    print("=" * 60)
    print("HID Report Descriptor (原始 hex)")
    print("=" * 60)
    try:
        # hidapi get_report_descriptor - needs buffer
        # Try the Python hid wrapper
        desc = device.get_report_descriptor()
        print(f"长度: {len(desc)} bytes")
        for i in range(0, len(desc), 16):
            hex_str = " ".join(f"{b:02x}" for b in desc[i:i+16])
            print(f"  {i:04x}: {hex_str}")
    except AttributeError:
        print("get_report_descriptor 方法不可用，改用 ioctl...")
        try:
            import fcntl, struct
            # HIDIOCGRDESCSIZE = _IOR('H', 0x01, int)
            # HIDIOCGRDESC = _IOR('H', 0x02, struct hidraw_report_descriptor)
            fd = os.open(path, os.O_RDONLY)
            # Get size
            desc_size = struct.unpack('i', fcntl.ioctl(fd, 0x80044801, struct.pack('i', 0)))[0]
            print(f"Report Descriptor 大小: {desc_size} bytes")
            # Get descriptor
            buf = struct.pack('i', desc_size) + b'\x00' * 4096
            result = fcntl.ioctl(fd, 0x90044802, buf)
            desc = result[4:4+desc_size]
            for i in range(0, len(desc), 16):
                hex_str = " ".join(f"{b:02x}" for b in desc[i:i+16])
                print(f"  {i:04x}: {hex_str}")
            os.close(fd)
        except Exception as e:
            print(f"ioctl 方法也失败: {e}")
    except Exception as e:
        print(f"获取 Report Descriptor 失败: {e}")

    # --- Re-test commands ---
    print("\n" + "=" * 60)
    print("命令重测 (带 vs 不带 0x02)")
    print("=" * 60)

    # 挡位灯 ON 命令
    cmd_body = bytes.fromhex("5aa54803014c")
    cmd_padded = cmd_body + b"\x00" * (23 - len(cmd_body))

    tests = [
        ("WITH 0x02 (Go current)", b"\x02" + cmd_padded[:-1]),
        ("WITHOUT 0x02", cmd_padded),
    ]

    for label, cmd in tests:
        print(f"\n--- {label} ---")
        hex_str = " ".join(f"{b:02x}" for b in cmd)
        print(f"发送: {hex_str}")
        result = device.write(cmd)
        print(f"write() = {result}")
        time.sleep(0.5)
        # read without timeout
        try:
            data = device.read(64, timeout_ms=500)
            if data:
                print(f"读取: {' '.join(f'{b:02x}' for b in data)}")
        except TypeError:
            try:
                data = device.read(64)
                if data:
                    print(f"读取: {' '.join(f'{b:02x}' for b in data)}")
            except:
                pass
        except:
            pass

    # Try a short command (7 bytes only, no padding)
    print("\n--- 测试: 7字节命令 (无填充) WITHOUT 0x02 ---")
    cmd7 = bytes.fromhex("5aa54803014c")
    print(f"发送 ({len(cmd7)} bytes): {' '.join(f'{b:02x}' for b in cmd7)}")
    result = device.write(cmd7)
    print(f"write() = {result}")
    time.sleep(0.5)

    print("\n--- 测试: 7字节命令 (无填充) WITH 0x02 ---")
    cmd7_02 = b"\x02" + bytes.fromhex("5aa54803014c")
    print(f"发送 ({len(cmd7_02)} bytes): {' '.join(f'{b:02x}' for b in cmd7_02)}")
    result = device.write(cmd7_02)
    print(f"write() = {result}")
    time.sleep(0.5)

    device.close()
    print("\n完成。请报告物理观察结果。")


if __name__ == "__main__":
    sys.exit(main())
