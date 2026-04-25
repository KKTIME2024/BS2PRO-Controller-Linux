#!/bin/bash

# BS2PRO-Controller Linux installation script
# This script installs systemd user service and udev rules

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root for user service installation."
        log_error "Please run as regular user for user service setup."
        exit 1
    fi
}

# Check if systemd is available
check_systemd() {
    if ! command -v systemctl &> /dev/null; then
        log_error "systemd is not available on this system."
        exit 1
    fi
    
    if ! systemctl --user --quiet is-active dbus.socket 2>/dev/null; then
        log_warn "systemd user session not active. Trying to start it..."
        systemctl --user import-environment DISPLAY XAUTHORITY 2>/dev/null || true
        if ! systemctl --user --quiet is-active dbus.socket 2>/dev/null; then
            log_error "Cannot start systemd user session. Please enable it first."
            log_error "You may need to run: loginctl enable-linger $USER"
            exit 1
        fi
    fi
}

# Install udev rules
install_udev_rules() {
    local udev_rules_src="$(dirname "$0")/../build/99-bs2pro-controller.rules"
    local udev_rules_dest="/etc/udev/rules.d/99-bs2pro-controller.rules"
    
    log_info "Installing udev rules for HID device access..."
    
    if [[ ! -f "$udev_rules_src" ]]; then
        log_error "Udev rules source file not found: $udev_rules_src"
        return 1
    fi
    
    # Copy udev rules (requires sudo)
    sudo cp "$udev_rules_src" "$udev_rules_dest"
    sudo chmod 644 "$udev_rules_dest"
    
    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    log_info "Udev rules installed successfully."
}

# Install systemd user service
install_systemd_service() {
    local service_src="$(dirname "$0")/../build/bs2pro-controller.user.service"
    local service_dest="$HOME/.config/systemd/user/bs2pro-controller.service"
    
    log_info "Installing systemd user service..."
    
    if [[ ! -f "$service_src" ]]; then
        log_error "Systemd service source file not found: $service_src"
        return 1
    fi
    
    # Create user systemd directory if it doesn't exist
    mkdir -p "$HOME/.config/systemd/user"
    
    # Copy service file
    cp "$service_src" "$service_dest"
    
    # Reload systemd user daemon
    systemctl --user daemon-reload
    
    log_info "Systemd user service installed successfully."
}

# Enable and start the service
enable_service() {
    log_info "Enabling and starting BS2PRO Controller service..."
    
    # Enable the service (starts on login)
    systemctl --user enable bs2pro-controller.service
    
    # Start the service now
    if systemctl --user start bs2pro-controller.service; then
        log_info "Service started successfully."
        
        # Check service status
        sleep 2
        if systemctl --user is-active bs2pro-controller.service >/dev/null; then
            log_info "Service is running. Checking status..."
            systemctl --user status bs2pro-controller.service --no-pager
        else
            log_warn "Service started but is not active. Checking logs..."
            journalctl --user -u bs2pro-controller.service -n 20 --no-pager
        fi
    else
        log_error "Failed to start service. Checking logs..."
        journalctl --user -u bs2pro-controller.service -n 20 --no-pager
        return 1
    fi
}

# Install desktop file for autostart
install_desktop_autostart() {
    local desktop_src="$(dirname "$0")/../build/bs2pro-controller.desktop"
    local autostart_dest="$HOME/.config/autostart/bs2pro-controller.desktop"
    
    log_info "Installing desktop autostart file..."
    
    if [[ ! -f "$desktop_src" ]]; then
        log_warn "Desktop file not found, creating default one..."
        create_default_desktop_file
        desktop_src="$(dirname "$0")/../build/bs2pro-controller.desktop"
    fi
    
    # Create autostart directory if it doesn't exist
    mkdir -p "$HOME/.config/autostart"
    
    # Copy desktop file
    cp "$desktop_src" "$autostart_dest"
    chmod 644 "$autostart_dest"
    
    log_info "Desktop autostart file installed successfully."
}

# Create default desktop file if it doesn't exist
create_default_desktop_file() {
    local desktop_file="$(dirname "$0")/../build/bs2pro-controller.desktop"
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Type=Application
Name=BS2PRO Controller
Comment=Control Flydigi BS2PRO cooling device
Exec=$HOME/.local/bin/BS2PRO-Controller
Icon=bs2pro-controller
Terminal=false
Categories=Utility;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
    
    log_info "Created default desktop file: $desktop_file"
}

# Check if binaries are installed
check_binaries() {
    local gui_bin="$HOME/.local/bin/BS2PRO-Controller"
    local core_bin="$HOME/.local/bin/BS2PRO-Core"
    
    if [[ ! -f "$gui_bin" ]] || [[ ! -f "$core_bin" ]]; then
        log_warn "BS2PRO Controller binaries not found in ~/.local/bin/"
        log_warn "Please build and install the binaries first:"
        log_warn "  make build && make install"
        log_warn "Or install manually to ~/.local/bin/"
        return 1
    fi
    
    log_info "Found binaries:"
    log_info "  GUI: $gui_bin"
    log_info "  Core: $core_bin"
    return 0
}

# Main installation function
main() {
    log_info "Starting BS2PRO Controller Linux installation..."
    
    # Check prerequisites
    check_root
    check_systemd
    
    # Check if binaries are installed
    if ! check_binaries; then
        log_warn "Continuing installation anyway, but service may not work without binaries."
        read -p "Do you want to continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation aborted."
            exit 0
        fi
    fi
    
    # Install components
    install_udev_rules
    install_systemd_service
    install_desktop_autostart
    
    # Enable and start service
    enable_service
    
    # Installation summary
    log_info ""
    log_info "========================================="
    log_info "Installation completed successfully!"
    log_info "========================================="
    log_info ""
    log_info "Service management commands:"
    log_info "  Start service: systemctl --user start bs2pro-controller"
    log_info "  Stop service:  systemctl --user stop bs2pro-controller"
    log_info "  Enable on login: systemctl --user enable bs2pro-controller"
    log_info "  Disable on login: systemctl --user disable bs2pro-controller"
    log_info "  Check status: systemctl --user status bs2pro-controller"
    log_info "  View logs: journalctl --user -u bs2pro-controller -f"
    log_info ""
    log_info "The application should now start automatically on login."
    log_info "You can also run the GUI manually: ~/.local/bin/BS2PRO-Controller"
    log_info ""
}

# Run main function
main "$@"