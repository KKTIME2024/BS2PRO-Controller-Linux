创建一个持久的udev规则，避免每次插拔都要chmod：创建规则文件：

bash

sudo nano /etc/udev/rules.d/99-flydigi-bs2.rules

粘贴以下内容：

# Flydigi BS2 散热器 HID 权限规则
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="37d7", ATTRS{idProduct}=="1001", MODE="0666", GROUP="plugdev"

保存后运行：

bash

sudo udevadm control --reload-rules
sudo udevadm trigger

以后每次插上BS2，应该就会自动有0666权限了。

2
创建持久化的udev规则（推荐长期使用，不依赖plugdev组）因为你的发行版可能没有plugdev，我们改成给所有用户读写权限（MODE="0666"），或者用 TAG+="uaccess"（systemd推荐方式，更安全）。创建规则文件：

bash

sudo nano /etc/udev/rules.d/99-flydigi-bs2.rules

把下面内容完整复制粘贴进去（推荐用这个版本，更通用）：

# Flydigi BS2 散热器 HID 权限（兼容无plugdev的发行版）
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="37d7", ATTRS{idProduct}=="1001", MODE="0666", TAG+="uaccess"

   （或者如果你想更严格只给当前用户，也可以试 MODE="0660" + GROUP="users"，但先用0666测试。）保存退出后，执行：

bash

sudo udevadm control --reload-rules
sudo udevadm trigger

拔掉BS2再重新插上（或重启电脑），然后检查权限：

bash

ls -la /dev/hidraw*

应该看到类似 crw-rw-rw-（666权限）。

