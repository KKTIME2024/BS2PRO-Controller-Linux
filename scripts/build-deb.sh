#!/bin/bash

# BS2PRO Controller Debian/Ubuntu package builder
# Usage: ./scripts/build-deb.sh [version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the project root
check_project_root() {
    if [ ! -f "Makefile" ] || [ ! -f "README.md" ]; then
        log_error "Please run this script from the project root directory"
        exit 1
    fi
}

# Get version from wails.json
get_version() {
    if [ -f "wails.json" ]; then
        grep '"productVersion"' wails.json | sed 's/.*: "\(.*\)".*/\1/'
    else
        echo "2.10.0"
    fi
}

# Create DEB package structure
create_deb_structure() {
    local version="$1"
    local arch="$2"
    local deb_dir="build/deb/bs2pro-controller_${version}_${arch}"
    
    log_info "Creating DEB package structure for $arch..."
    
    # Clean and create directories
    rm -rf "build/deb"
    mkdir -p "$deb_dir/DEBIAN"
    mkdir -p "$deb_dir/usr/bin"
    mkdir -p "$deb_dir/usr/lib/systemd/user"
    mkdir -p "$deb_dir/usr/lib/udev/rules.d"
    mkdir -p "$deb_dir/usr/share/applications"
    mkdir -p "$deb_dir/usr/share/icons/hicolor/256x256/apps"
    mkdir -p "$deb_dir/usr/share/doc/bs2pro-controller"
    mkdir -p "$deb_dir/usr/share/bs2pro-controller"
    mkdir -p "$deb_dir/etc/default"
    
    echo "$deb_dir"
}

# Build the application
build_application() {
    log_info "Building application..."
    
    # Clean previous builds
    make clean
    
    # Build for current architecture
    make build
    
    # Verify build
    if [ ! -f "build/bin/BS2PRO-Controller" ] || [ ! -f "build/bin/BS2PRO-Core" ]; then
        log_error "Build failed - binaries not found"
        exit 1
    fi
    
    log_info "Build completed successfully"
}

# Create DEBIAN control file
create_control_file() {
    local version="$1"
    local arch="$2"
    local deb_dir="$3"
    
    # Map Go architecture to Debian architecture
    case "$arch" in
        "amd64")
            deb_arch="amd64"
            ;;
        "arm64")
            deb_arch="arm64"
            ;;
        "386")
            deb_arch="i386"
            ;;
        "arm")
            deb_arch="armhf"
            ;;
        *)
            deb_arch="$arch"
            ;;
    esac
    
    cat > "$deb_dir/DEBIAN/control" << EOF
Package: bs2pro-controller
Version: ${version}
Section: utils
Priority: optional
Architecture: ${deb_arch}
Depends: libudev1, libusb-1.0-0, lm-sensors
Recommends: nvidia-smi | rocm-smi | intel-gpu-tools
Suggests: wails
Maintainer: KKTIME2024 <github@kktime2024.org>
Description: Linux port of BS2PRO Controller
 BS2PRO Controller is a Linux port of the Windows application for controlling
 Flydigi BS1/2/2PRO cooling devices. It provides fan control, temperature
 monitoring, and RGB lighting control.
 .
 Features:
  - Control Flydigi BS1/2/2PRO cooling devices
  - Real-time CPU/GPU temperature monitoring
  - Automatic fan speed control based on temperature
  - Custom fan curves and profiles
  - System tray integration
  - Systemd service for background operation
  - Automatic startup on login
Homepage: https://github.com/KKTIME2024/BS2PRO-Controller-Linux
EOF
}

# Create post-install script
create_postinst_script() {
    local deb_dir="$1"
    
    cat > "$deb_dir/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Update icon cache
if [ -x "$(command -v update-desktop-database)" ]; then
    update-desktop-database -q 2>/dev/null || true
fi

if [ -x "$(command -v gtk-update-icon-cache)" ]; then
    gtk-update-icon-cache -qtf /usr/share/icons/hicolor 2>/dev/null || true
fi

# Reload udev rules
if [ -f /usr/lib/udev/rules.d/99-bs2pro-controller.rules ]; then
    udevadm control --reload-rules
    udevadm trigger
fi

# Create user message
cat << MESSAGE
========================================================
BS2PRO Controller installation complete!
========================================================

To complete setup:

1. Add your user to the 'plugdev' group:
   sudo usermod -aG plugdev $USER

2. Enable systemd user service:
   systemctl --user enable bs2pro-controller

3. Start the service:
   systemctl --user start bs2pro-controller

4. Log out and log back in for group changes.

You can run the GUI with: BS2PRO-Controller

For more information: /usr/share/doc/bs2pro-controller/README.md
========================================================
MESSAGE

exit 0
EOF
    chmod 755 "$deb_dir/DEBIAN/postinst"
}

# Create post-remove script
create_postrm_script() {
    local deb_dir="$1"
    
    cat > "$deb_dir/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

# Stop and disable service if removing
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    # Stop user service if running
    if [ -x "$(command -v systemctl)" ]; then
        systemctl --user stop bs2pro-controller 2>/dev/null || true
        systemctl --user disable bs2pro-controller 2>/dev/null || true
    fi
fi

# Purge configuration files
if [ "$1" = "purge" ]; then
    # Remove user configuration
    rm -rf ~/.config/bs2pro-controller
    rm -rf ~/.cache/bs2pro-controller
    rm -f ~/.config/autostart/bs2pro-controller.desktop
fi

exit 0
EOF
    chmod 755 "$deb_dir/DEBIAN/postrm"
}

# Copy files to DEB structure
copy_files_to_deb() {
    local deb_dir="$1"
    
    log_info "Copying files to DEB structure..."
    
    # Copy binaries
    cp -v "build/bin/BS2PRO-Controller" "$deb_dir/usr/bin/"
    cp -v "build/bin/BS2PRO-Core" "$deb_dir/usr/bin/"
    
    # Copy system files
    cp -v "build/bs2pro-controller.user.service" "$deb_dir/usr/lib/systemd/user/bs2pro-controller.service"
    cp -v "build/99-bs2pro-controller.rules" "$deb_dir/usr/lib/udev/rules.d/99-bs2pro-controller.rules"
    cp -v "build/bs2pro-controller.desktop" "$deb_dir/usr/share/applications/"
    
    # Copy icon if exists
    if [ -f "build/appicon.png" ]; then
        cp -v "build/appicon.png" "$deb_dir/usr/share/icons/hicolor/256x256/apps/bs2pro-controller.png"
    fi
    
    # Copy documentation
    cp -v README.md "$deb_dir/usr/share/doc/bs2pro-controller/"
    cp -v LINUX-PORT-PLAN.md "$deb_dir/usr/share/doc/bs2pro-controller/"
    cp -v LICENSE "$deb_dir/usr/share/doc/bs2pro-controller/copyright"
    
    # Copy helper scripts
    cp -v "scripts/install-systemd.sh" "$deb_dir/usr/share/bs2pro-controller/"
    cp -v "scripts/uninstall-systemd.sh" "$deb_dir/usr/share/bs2pro-controller/"
    
    # Create README.Debian
    cat > "$deb_dir/usr/share/doc/bs2pro-controller/README.Debian" << 'EOF'
BS2PRO Controller for Debian/Ubuntu
===================================

This package provides a Linux port of the BS2PRO Controller application
for controlling Flydigi BS1/2/2PRO cooling devices.

Quick Start:
1. Install the package: sudo dpkg -i bs2pro-controller_*.deb
2. Add user to plugdev group: sudo usermod -aG plugdev $USER
3. Enable service: systemctl --user enable bs2pro-controller
4. Start service: systemctl --user start bs2pro-controller
5. Log out and back in

The application will start automatically on login. You can also run
the GUI manually: BS2PRO-Controller

For troubleshooting, check logs: journalctl --user -u bs2pro-controller

See /usr/share/doc/bs2pro-controller/README.md for full documentation.
EOF
    
    # Compress documentation
    gzip -9n "$deb_dir/usr/share/doc/bs2pro-controller/README.Debian" 2>/dev/null || true
    
    # Set permissions
    find "$deb_dir" -type f -exec chmod 644 {} \;
    find "$deb_dir/usr/bin" -type f -exec chmod 755 {} \;
    find "$deb_dir/DEBIAN" -type f -exec chmod 755 {} \;
    find "$deb_dir/usr/share/bs2pro-controller" -type f -exec chmod 755 {} \;
}

# Build the DEB package
build_deb_package() {
    local deb_dir="$1"
    local output_dir="build/deb"
    
    log_info "Building DEB package..."
    
    # Build package
    dpkg-deb --build --root-owner-group "$deb_dir"
    
    # Move to output directory
    mv "${deb_dir}.deb" "$output_dir/"
    
    log_info "DEB package built: $output_dir/$(basename ${deb_dir}).deb"
}

# Main function
main() {
    # Check project root
    check_project_root
    
    # Get version
    local version="${1:-$(get_version)}"
    log_info "Building version: $version"
    
    # Get architecture
    local arch="$(go env GOARCH 2>/dev/null || echo "amd64")"
    log_info "Target architecture: $arch"
    
    # Build application
    build_application
    
    # Create DEB structure
    local deb_dir=$(create_deb_structure "$version" "$arch")
    
    # Create control file
    create_control_file "$version" "$arch" "$deb_dir"
    
    # Create scripts
    create_postinst_script "$deb_dir"
    create_postrm_script "$deb_dir"
    
    # Copy files
    copy_files_to_deb "$deb_dir"
    
    # Build package
    build_deb_package "$deb_dir"
    
    log_info ""
    log_info "========================================================"
    log_info "DEB package build completed successfully!"
    log_info "Package: build/deb/bs2pro-controller_${version}_${arch}.deb"
    log_info "========================================================"
}

# Run main function
main "$@"