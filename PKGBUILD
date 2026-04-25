# Maintainer: KKTIME2024 <github@kktime2024.org>
pkgname=bs2pro-controller
pkgver=2.10.0
pkgrel=1
pkgdesc="Linux port of BS2PRO Controller - control Flydigi BS1/2/2PRO cooling devices"
arch=('x86_64' 'aarch64')
url="https://github.com/KKTIME2024/BS2PRO-Controller-Linux"
license=('MIT')
depends=(
  'go>=1.21'
  'nodejs>=18'
  'bun'
  'libudev'
  'libusb'
  'lm_sensors'  # for temperature monitoring
)
makedepends=(
  'git'
  'make'
)
optdepends=(
  'nvidia-utils: NVIDIA GPU temperature monitoring'
  'rocm-smi-lib: AMD GPU temperature monitoring'
  'intel-gpu-tools: Intel GPU temperature monitoring'
)
provides=('bs2pro-controller')
conflicts=('bs2pro-controller')
backup=('etc/udev/rules.d/99-bs2pro-controller.rules')
source=("$pkgname-$pkgver.tar.gz::https://github.com/KKTIME2024/BS2PRO-Controller-Linux/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

prepare() {
  cd "$pkgname-$pkgver"
  
  # Check if we need to download submodules
  if [ ! -f "frontend/package.json" ]; then
    echo "Downloading frontend dependencies..."
    mkdir -p frontend
    curl -L https://github.com/KKTIME2024/BS2PRO-Controller-Linux/releases/download/v$pkgver/frontend.tar.gz | tar xz -C frontend/
  fi
}

build() {
  cd "$pkgname-$pkgver"
  
  echo "Building BS2PRO Controller..."
  
  # Install Go dependencies
  go mod download
  
  # Build the application
  make build
  
  # Verify binaries were built
  if [ ! -f "build/bin/BS2PRO-Controller" ] || [ ! -f "build/bin/BS2PRO-Core" ]; then
    echo "ERROR: Binaries were not built successfully"
    exit 1
  fi
}

package() {
  cd "$pkgname-$pkgver"
  
  # Create directories
  install -dm755 "$pkgdir"/usr/{bin,lib/systemd/user,lib/udev/rules.d}
  install -dm755 "$pkgdir"/usr/share/{applications,icons/hicolor/256x256/apps,licenses/$pkgname}
  
  # Install binaries
  install -Dm755 "build/bin/BS2PRO-Controller" "$pkgdir/usr/bin/BS2PRO-Controller"
  install -Dm755 "build/bin/BS2PRO-Core" "$pkgdir/usr/bin/BS2PRO-Core"
  
  # Install systemd user service
  install -Dm644 "build/bs2pro-controller.user.service" "$pkgdir/usr/lib/systemd/user/bs2pro-controller.service"
  
  # Install udev rules
  install -Dm644 "build/99-bs2pro-controller.rules" "$pkgdir/usr/lib/udev/rules.d/99-bs2pro-controller.rules"
  
  # Install desktop file
  install -Dm644 "build/bs2pro-controller.desktop" "$pkgdir/usr/share/applications/bs2pro-controller.desktop"
  
  # Install icon (if exists)
  if [ -f "build/appicon.png" ]; then
    install -Dm644 "build/appicon.png" "$pkgdir/usr/share/icons/hicolor/256x256/apps/bs2pro-controller.png"
  fi
  
  # Install license
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  
  # Install documentation
  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
  install -Dm644 LINUX-PORT-PLAN.md "$pkgdir/usr/share/doc/$pkgname/LINUX-PORT-PLAN.md"
  
  # Install installation helper script
  install -Dm755 "scripts/install-systemd.sh" "$pkgdir/usr/share/$pkgname/install-systemd.sh"
  install -Dm755 "scripts/uninstall-systemd.sh" "$pkgdir/usr/share/$pkgname/uninstall-systemd.sh"
  
  # Create a wrapper script for user installation
  cat > "$pkgdir/usr/bin/bs2pro-controller-install" << 'EOF'
#!/bin/bash
# BS2PRO Controller installation helper script

set -e

echo "BS2PRO Controller installation helper"
echo "====================================="
echo ""
echo "This package provides the following installation options:"
echo ""
echo "1. Basic installation (binaries only)"
echo "   The binaries are installed to /usr/bin/"
echo ""
echo "2. System integration (recommended)"
echo "   Run the following commands:"
echo ""
echo "   # Install udev rules (requires sudo)"
echo "   sudo udevadm control --reload-rules"
echo "   sudo udevadm trigger"
echo ""
echo "   # Enable systemd user service"
echo "   systemctl --user enable bs2pro-controller"
echo "   systemctl --user start bs2pro-controller"
echo ""
echo "3. Complete setup script"
echo "   Run: /usr/share/bs2pro-controller/install-systemd.sh"
echo ""
echo "For more information, see /usr/share/doc/bs2pro-controller/README.md"
EOF
  chmod 755 "$pkgdir/usr/bin/bs2pro-controller-install"
  
  # Create post-installation message
  mkdir -p "$pkgdir/usr/share/$pkgname"
  cat > "$pkgdir/usr/share/$pkgname/post-install.txt" << 'EOF'
BS2PRO Controller has been installed successfully!

To complete the setup:

1. Add your user to the 'plugdev' group to access HID devices:
   sudo usermod -aG plugdev $USER

2. Reload udev rules and trigger device detection:
   sudo udevadm control --reload-rules
   sudo udevadm trigger

3. Enable and start the systemd user service:
   systemctl --user enable bs2pro-controller
   systemctl --user start bs2pro-controller

4. Log out and log back in for group changes to take effect.

You can now run the application:
- GUI: BS2PRO-Controller
- Service status: systemctl --user status bs2pro-controller
- Logs: journalctl --user -u bs2pro-controller -f

For more information, see /usr/share/doc/bs2pro-controller/README.md
EOF
}

post_install() {
  echo "========================================================"
  echo "BS2PRO Controller installation complete!"
  echo ""
  cat /usr/share/bs2pro-controller/post-install.txt
  echo "========================================================"
}

post_upgrade() {
  # Reload systemd user daemon if service file changed
  systemctl --user daemon-reload 2>/dev/null || true
  
  # Restart service if it's running
  if systemctl --user is-active bs2pro-controller >/dev/null 2>&1; then
    systemctl --user restart bs2pro-controller
  fi
}

post_remove() {
  # Stop service if it's running
  if systemctl --user is-active bs2pro-controller >/dev/null 2>&1; then
    systemctl --user stop bs2pro-controller
  fi
  
  # Disable service
  systemctl --user disable bs2pro-controller 2>/dev/null || true
}