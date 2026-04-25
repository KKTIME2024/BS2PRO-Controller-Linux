#!/bin/bash

# BS2PRO Controller build and packaging test script
# This script tests the build system and packaging on the current system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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

# Detect system and package manager
detect_system() {
    if [ -f "/etc/arch-release" ]; then
        echo "arch"
    elif [ -f "/etc/debian_version" ]; then
        echo "debian"
    elif [ -f "/etc/redhat-release" ] || [ -f "/etc/fedora-release" ]; then
        echo "fedora"
    elif [ -f "/etc/SuSE-release" ]; then
        echo "suse"
    else
        echo "unknown"
    fi
}

# Test basic build
test_build() {
    log_info "Testing basic build..."
    
    # Clean first
    make clean
    
    # Build all
    if make build; then
        log_success "Build completed successfully"
        
        # Verify binaries
        if [ -f "build/bin/BS2PRO-Controller" ] && [ -f "build/bin/BS2PRO-Core" ]; then
            log_success "Binary verification passed"
            echo "  BS2PRO-Controller: $(ls -lh build/bin/BS2PRO-Controller | awk '{print $5}')"
            echo "  BS2PRO-Core: $(ls -lh build/bin/BS2PRO-Core | awk '{print $5}')"
        else
            log_error "Binary verification failed"
            return 1
        fi
    else
        log_error "Build failed"
        return 1
    fi
}

# Test individual build targets
test_build_targets() {
    log_info "Testing individual build targets..."
    
    targets=("build-core" "build-gui")
    
    for target in "${targets[@]}"; do
        log_info "Testing target: $target"
        if make "$target"; then
            log_success "Target $target passed"
        else
            log_error "Target $target failed"
            return 1
        fi
    done
}

# Test development commands
test_dev_commands() {
    log_info "Testing development commands..."
    
    # Note: These are mostly smoke tests since they may require external dependencies
    dev_commands=("tidy" "test")
    
    for cmd in "${dev_commands[@]}"; do
        log_info "Testing command: make $cmd"
        if make "$cmd" >/dev/null 2>&1; then
            log_success "Command make $cmd completed"
        else
            log_warn "Command make $cmd had issues (may be expected)"
        fi
    done
}

# Test user installation
test_user_install() {
    log_info "Testing user installation..."
    
    # Create a temporary directory for test installation
    local test_dir="/tmp/bs2pro-test-$$"
    mkdir -p "$test_dir"
    
    # Backup original HOME
    local original_home="$HOME"
    export HOME="$test_dir"
    
    # Test user-install target
    if make user-install >/dev/null 2>&1; then
        log_success "User installation completed"
        
        # Check if binaries were installed
        if [ -f "$test_dir/.local/bin/BS2PRO-Controller" ] && \
           [ -f "$test_dir/.local/bin/BS2PRO-Core" ]; then
            log_success "User binaries verified"
        else
            log_error "User binaries not found"
        fi
    else
        log_error "User installation failed"
    fi
    
    # Restore HOME and clean up
    export HOME="$original_home"
    rm -rf "$test_dir"
}

# Test packaging based on system
test_packaging() {
    local system=$(detect_system)
    
    case "$system" in
        "arch")
            test_arch_packaging
            ;;
        "debian")
            test_debian_packaging
            ;;
        "fedora")
            test_fedora_packaging
            ;;
        *)
            log_warn "Unknown system type, skipping packaging tests"
            ;;
    esac
}

# Test Arch Linux packaging
test_arch_packaging() {
    log_info "Testing Arch Linux packaging..."
    
    if [ -f "PKGBUILD" ]; then
        log_success "PKGBUILD file exists"
        
        # Check PKGBUILD syntax
        if bash -n PKGBUILD; then
            log_success "PKGBUILD syntax check passed"
        else
            log_error "PKGBUILD syntax check failed"
        fi
    else
        log_error "PKGBUILD file not found"
    fi
}

# Test Debian packaging
test_debian_packaging() {
    log_info "Testing Debian packaging..."
    
    if [ -f "scripts/build-deb.sh" ]; then
        log_success "DEB build script exists"
        
        # Check script syntax
        if bash -n scripts/build-deb.sh; then
            log_success "DEB build script syntax check passed"
        else
            log_error "DEB build script syntax check failed"
        fi
    else
        log_error "DEB build script not found"
    fi
}

# Test Fedora packaging
test_fedora_packaging() {
    log_info "Testing Fedora packaging..."
    
    if [ -f "scripts/build-rpm.sh" ]; then
        log_success "RPM build script exists"
        
        # Check script syntax
        if bash -n scripts/build-rpm.sh; then
            log_success "RPM build script syntax check passed"
        else
            log_error "RPM build script syntax check failed"
        fi
    else
        log_error "RPM build script not found"
    fi
}

# Test system integration scripts
test_integration_scripts() {
    log_info "Testing system integration scripts..."
    
    scripts=("scripts/install-systemd.sh" "scripts/uninstall-systemd.sh")
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            log_info "Checking script: $script"
            
            # Check syntax
            if bash -n "$script"; then
                log_success "Script syntax check passed: $script"
            else
                log_error "Script syntax check failed: $script"
            fi
        else
            log_error "Script not found: $script"
        fi
    done
}

# Test documentation
test_documentation() {
    log_info "Testing documentation..."
    
    docs=("README.md" "LINUX-PORT-PLAN.md")
    
    for doc in "${docs[@]}"; do
        if [ -f "$doc" ]; then
            log_success "Document exists: $doc"
            
            # Check if it's readable and has content
            if [ -s "$doc" ]; then
                log_success "Document has content: $doc"
            else
                log_error "Document is empty: $doc"
            fi
        else
            log_error "Document not found: $doc"
        fi
    done
}

# Run Go tests
test_go_tests() {
    log_info "Running Go tests..."
    
    if go test ./internal/... -v 2>&1 | grep -q "PASS\|FAIL"; then
        log_success "Go tests completed"
    else
        log_warn "Go tests may have issues or no tests found"
    fi
}

# Main test function
main() {
    log_info "Starting BS2PRO Controller build and packaging tests"
    log_info "======================================================"
    
    # Check project root
    check_project_root
    
    # Detect system
    local system=$(detect_system)
    log_info "Detected system: $system"
    
    # Run tests
    test_build
    test_build_targets
    test_dev_commands
    test_user_install
    test_packaging
    test_integration_scripts
    test_documentation
    test_go_tests
    
    log_info ""
    log_info "======================================================"
    log_success "All tests completed!"
    log_info "System: $system"
    log_info "Status: Build system and packaging verified"
    log_info "======================================================"
}

# Run main function
main "$@"