#!/bin/bash

# BS2PRO Controller RPM package builder
# Usage: ./scripts/build-rpm.sh [version]

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

# Check if rpmbuild is available
check_rpmbuild() {
    if ! command -v rpmbuild &> /dev/null; then
        log_error "rpmbuild not found. Please install rpm-build package."
        log_error "Fedora/CentOS/RHEL: sudo dnf install rpm-build"
        log_error "openSUSE: sudo zypper install rpm-build"
        exit 1
    fi
}

# Create RPM build structure
create_rpm_structure() {
    local version="$1"
    local rpm_dir="$HOME/rpmbuild"
    
    log_info "Creating RPM build structure..."
    
    # Create RPM directories
    mkdir -p "$rpm_dir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
    
    # Create source tarball
    local pkgname="bs2pro-controller"
    local pkgver="$version"
    
    # Clean previous builds
    rm -rf "build/rpm"
    mkdir -p "build/rpm"
    
    # Create source directory
    local src_dir="build/rpm/$pkgname-$pkgver"
    mkdir -p "$src_dir"
    
    # Copy source files
    cp -r * "$src_dir/" 2>/dev/null || true
    
    # Create tarball
    tar -czf "$rpm_dir/SOURCES/$pkgname-$pkgver.tar.gz" -C "build/rpm" "$pkgname-$pkgver"
    
    echo "$pkgname $pkgver $rpm_dir"
}

# Create RPM spec file
create_spec_file() {
    local pkgname="$1"
    local pkgver="$2"
    local rpm_dir="$3"
    
    log_info "Creating RPM spec file..."
    
    cat > "$rpm_dir/SPECS/$pkgname.spec" << EOF
Name:           $pkgname
Version:        $pkgver
Release:        1%{?dist}
Summary:        Linux port of BS2PRO Controller for Flydigi cooling devices
License:        MIT
URL:            https://github.com/KKTIME2024/BS2PRO-Controller-Linux
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  golang >= 1.21
BuildRequires:  nodejs >= 18
BuildRequires:  bun
BuildRequires:  systemd
BuildRequires:  make
Requires:       systemd
Requires:       libudev
Requires:       libusb
Requires:       lm_sensors
Suggests:       nvidia-smi
Suggests:       rocm-smi
Suggests:       intel-gpu-tools

%description
BS2PRO Controller is a Linux port of the Windows application for controlling
Flydigi BS1/2/2PRO cooling devices. It provides fan control, temperature
monitoring, and RGB lighting control.

Features:
- Control Flydigi BS1/2/2PRO cooling devices
- Real-time CPU/GPU temperature monitoring
- Automatic fan speed control based on temperature
- Custom fan curves and profiles
- System tray integration
- Systemd service for background operation
- Automatic startup on login

%prep
%setup -q

%build
# Build the application
make build

%install
rm -rf %{buildroot}

# Install binaries
install -Dm755 build/bin/BS2PRO-Controller %{buildroot}/%{_bindir}/BS2PRO-Controller
install -Dm755 build/bin/BS2PRO-Core %{buildroot}/%{_bindir}/BS2PRO-Core

# Install systemd user service
install -Dm644 build/bs2pro-controller.user.service %{buildroot}/%{_userunitdir}/bs2pro-controller.service

# Install udev rules
install -Dm644 build/99-bs2pro-controller.rules %{buildroot}/%{_udevrulesdir}/99-bs2pro-controller.rules

# Install desktop file
install -Dm644 build/bs2pro-controller.desktop %{buildroot}/%{_datadir}/applications/bs2pro-controller.desktop

# Install icon if exists
if [ -f build/appicon.png ]; then
    install -Dm644 build/appicon.png %{buildroot}/%{_datadir}/icons/hicolor/256x256/apps/bs2pro-controller.png
fi

# Install documentation
install -Dm644 README.md %{buildroot}/%{_docdir}/%{name}/README.md
install -Dm644 LINUX-PORT-PLAN.md %{buildroot}/%{_docdir}/%{name}/LINUX-PORT-PLAN.md
install -Dm644 LICENSE %{buildroot}/%{_docdir}/%{name}/LICENSE

# Install helper scripts
install -Dm755 scripts/install-systemd.sh %{buildroot}/%{_datadir}/%{name}/install-systemd.sh
install -Dm755 scripts/uninstall-systemd.sh %{buildroot}/%{_datadir}/%{name}/uninstall-systemd.sh

%post
# Update icon cache
if [ -x "%{_bindir}/update-desktop-database" ]; then
    update-desktop-database -q %{_datadir}/applications 2>/dev/null || true
fi

if [ -x "%{_bindir}/gtk-update-icon-cache" ]; then
    gtk-update-icon-cache -qtf %{_datadir}/icons/hicolor 2>/dev/null || true
fi

# Reload udev rules
if [ -f "%{_udevrulesdir}/99-bs2pro-controller.rules" ]; then
    %{_sbindir}/udevadm control --reload-rules
    %{_sbindir}/udevadm trigger
fi

# Systemd user daemon reload
if [ -x "%{_bindir}/systemctl" ]; then
    systemctl --user daemon-reload 2>/dev/null || true
fi

echo "========================================================"
echo "BS2PRO Controller installation complete!"
echo ""
echo "To complete setup:"
echo ""
echo "1. Add your user to required groups:"
echo "   sudo usermod -aG plugdev \$USER"
echo ""
echo "2. Enable systemd user service:"
echo "   systemctl --user enable bs2pro-controller"
echo ""
echo "3. Start the service:"
echo "   systemctl --user start bs2pro-controller"
echo ""
echo "4. Log out and log back in for group changes."
echo ""
echo "You can run the GUI with: BS2PRO-Controller"
echo ""
echo "For more information: %{_docdir}/%{name}/README.md"
echo "========================================================"

%postun
# Systemd user daemon reload
if [ -x "%{_bindir}/systemctl" ]; then
    systemctl --user daemon-reload 2>/dev/null || true
fi

# If uninstalling, stop and disable service
if [ \$1 -eq 0 ]; then
    if systemctl --user is-active bs2pro-controller >/dev/null 2>&1; then
        systemctl --user stop bs2pro-controller 2>/dev/null || true
    fi
    systemctl --user disable bs2pro-controller 2>/dev/null || true
fi

%preun
# If upgrading, stop service before upgrade
if [ \$1 -eq 1 ]; then
    if systemctl --user is-active bs2pro-controller >/dev/null 2>&1; then
        systemctl --user stop bs2pro-controller 2>/dev/null || true
    fi
fi

%files
%license LICENSE
%doc README.md LINUX-PORT-PLAN.md
%{_bindir}/BS2PRO-Controller
%{_bindir}/BS2PRO-Core
%{_userunitdir}/bs2pro-controller.service
%{_udevrulesdir}/99-bs2pro-controller.rules
%{_datadir}/applications/bs2pro-controller.desktop
%{_datadir}/%{name}/install-systemd.sh
%{_datadir}/%{name}/uninstall-systemd.sh
%{_docdir}/%{name}/LICENSE

%files -f icon.files
%{_datadir}/icons/hicolor/256x256/apps/bs2pro-controller.png

%changelog
* $(date +"%a %b %d %Y") KKTIME2024 <github@kktime2024.org> - $pkgver-1
- Initial RPM package for BS2PRO Controller Linux port
EOF

    # Create icon.files if icon exists
    if [ -f "build/appicon.png" ]; then
        echo "%{_datadir}/icons/hicolor/256x256/apps/bs2pro-controller.png" > "$rpm_dir/SPECS/icon.files"
    else
        touch "$rpm_dir/SPECS/icon.files"
    fi
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

# Build RPM package
build_rpm_package() {
    local pkgname="$1"
    local rpm_dir="$2"
    
    log_info "Building RPM package..."
    
    # Build the RPM
    rpmbuild -ba "$rpm_dir/SPECS/$pkgname.spec"
    
    # Find and copy the built RPM
    local rpm_file=$(find "$rpm_dir/RPMS" -name "*.rpm" | head -1)
    if [ -n "$rpm_file" ]; then
        mkdir -p "build/rpm"
        cp "$rpm_file" "build/rpm/"
        log_info "RPM package built: build/rpm/$(basename $rpm_file)"
    else
        log_error "Failed to find built RPM package"
        exit 1
    fi
}

# Main function
main() {
    # Check project root
    check_project_root
    
    # Check rpmbuild
    check_rpmbuild
    
    # Get version
    local version="${1:-$(get_version)}"
    log_info "Building version: $version"
    
    # Build application first
    build_application
    
    # Create RPM structure
    local result=$(create_rpm_structure "$version")
    local pkgname=$(echo $result | cut -d' ' -f1)
    local pkgver=$(echo $result | cut -d' ' -f2)
    local rpm_dir=$(echo $result | cut -d' ' -f3)
    
    # Create spec file
    create_spec_file "$pkgname" "$pkgver" "$rpm_dir"
    
    # Build RPM package
    build_rpm_package "$pkgname" "$rpm_dir"
    
    log_info ""
    log_info "========================================================"
    log_info "RPM package build completed successfully!"
    log_info "RPM packages are in: $rpm_dir/RPMS/"
    log_info "Copied to: build/rpm/"
    log_info "========================================================"
}

# Run main function
main "$@"