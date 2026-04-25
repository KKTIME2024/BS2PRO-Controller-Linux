#!/bin/bash

# BS2PRO-Controller Linux uninstallation script
# This script removes systemd user service and udev rules

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

# Remove systemd user service
remove_systemd_service() {
    log_info "Removing systemd user service..."
    
    # Stop the service if running
    if systemctl --user is-active bs2pro-controller.service >/dev/null 2>&1; then
        log_info "Stopping service..."
        systemctl --user stop bs2pro-controller.service
    fi
    
    # Disable the service
    if systemctl --user is-enabled bs2pro-controller.service >/dev/null 2>&1; then
        log_info "Disabling service..."
        systemctl --user disable bs2pro-controller.service
    fi
    
    # Remove service file
    local service_file="$HOME/.config/systemd/user/bs2pro-controller.service"
    if [[ -f "$service_file" ]]; then
        rm -f "$service_file"
        log_info "Removed service file: $service_file"
    fi
    
    # Reload systemd user daemon
    systemctl --user daemon-reload
    
    log_info "Systemd user service removed successfully."
}

# Remove udev rules
remove_udev_rules() {
    local udev_rules_dest="/etc/udev/rules.d/99-bs2pro-controller.rules"
    
    log_info "Removing udev rules..."
    
    if [[ -f "$udev_rules_dest" ]]; then
        # Remove udev rules (requires sudo)
        sudo rm -f "$udev_rules_dest"
        
        # Reload udev rules
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        
        log_info "Udev rules removed successfully."
    else
        log_info "Udev rules not found, skipping."
    fi
}

# Remove desktop autostart file
remove_desktop_autostart() {
    local autostart_file="$HOME/.config/autostart/bs2pro-controller.desktop"
    
    log_info "Removing desktop autostart file..."
    
    if [[ -f "$autostart_file" ]]; then
        rm -f "$autostart_file"
        log_info "Removed autostart file: $autostart_file"
    else
        log_info "Autostart file not found, skipping."
    fi
}

# Clean up configuration files
cleanup_config() {
    local config_dir="$HOME/.config/bs2pro-controller"
    local cache_dir="$HOME/.cache/bs2pro-controller"
    
    log_info "Cleaning up configuration and cache files..."
    
    # Ask user if they want to remove config files
    read -p "Remove configuration files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -d "$config_dir" ]]; then
            rm -rf "$config_dir"
            log_info "Removed config directory: $config_dir"
        fi
        
        if [[ -d "$cache_dir" ]]; then
            rm -rf "$cache_dir"
            log_info "Removed cache directory: $cache_dir"
        fi
        
        # Remove logs
        local log_dir="$HOME/.local/share/bs2pro-controller/logs"
        if [[ -d "$log_dir" ]]; then
            rm -rf "$log_dir"
            log_info "Removed log directory: $log_dir"
        fi
    else
        log_info "Configuration files preserved."
    fi
}

# Remove binaries (optional)
remove_binaries() {
    local gui_bin="$HOME/.local/bin/BS2PRO-Controller"
    local core_bin="$HOME/.local/bin/BS2PRO-Core"
    
    log_info "Checking for installed binaries..."
    
    read -p "Remove application binaries from ~/.local/bin/? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ -f "$gui_bin" ]]; then
            rm -f "$gui_bin"
            log_info "Removed GUI binary: $gui_bin"
        fi
        
        if [[ -f "$core_bin" ]]; then
            rm -f "$core_bin"
            log_info "Removed core binary: $core_bin"
        fi
    else
        log_info "Binaries preserved."
    fi
}

# Main uninstallation function
main() {
    log_info "Starting BS2PRO Controller Linux uninstallation..."
    
    # Remove components
    remove_systemd_service
    remove_desktop_autostart
    remove_udev_rules
    
    # Cleanup files
    cleanup_config
    
    # Remove binaries (optional)
    remove_binaries
    
    # Uninstallation summary
    log_info ""
    log_info "========================================="
    log_info "Uninstallation completed successfully!"
    log_info "========================================="
    log_info ""
    log_info "All system components have been removed."
    log_info "You may need to log out and log back in for changes to take full effect."
    log_info ""
}

# Run main function
main "$@"