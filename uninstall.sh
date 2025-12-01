#!/usr/bin/env bash

# Uninstallation script for theodo-scan CLI

set -e

# Colors
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'

print_success() {
    echo -e "${COLOR_GREEN}✓ $1${COLOR_RESET}"
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ $1${COLOR_RESET}"
}

print_error() {
    echo -e "${COLOR_RED}Error: $1${COLOR_RESET}" >&2
}

print_warning() {
    echo -e "${COLOR_YELLOW}Warning: $1${COLOR_RESET}"
}

# Check if running with sufficient permissions
check_permissions() {
    if [ -w "$1" ]; then
        return 0
    else
        return 1
    fi
}

# Main uninstallation function
uninstall_cli() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Theodo Scan CLI - Uninstallation    ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Installation directory
    INSTALL_DIR="/usr/local/bin"
    SYMLINK_TARGET="$INSTALL_DIR/theodo-scan"

    # Check if theodo-scan is installed
    if [ ! -e "$SYMLINK_TARGET" ] && [ ! -L "$SYMLINK_TARGET" ]; then
        print_error "theodo-scan is not installed at $SYMLINK_TARGET"
        exit 1
    fi

    print_info "Found theodo-scan installation"

    # Show where it's linked to if it's a symlink
    if [ -L "$SYMLINK_TARGET" ]; then
        TARGET=$(readlink "$SYMLINK_TARGET")
        print_info "Currently linked to: $TARGET"
    fi

    echo ""

    # Check permissions
    if ! check_permissions "$INSTALL_DIR"; then
        print_warning "No write permission to $INSTALL_DIR"
        print_info "Using sudo for uninstallation..."
        USE_SUDO=true
    else
        USE_SUDO=false
    fi

    # Remove symlink or executable
    if [ "$USE_SUDO" = true ]; then
        sudo rm -f "$SYMLINK_TARGET"
    else
        rm -f "$SYMLINK_TARGET"
    fi
    print_success "Removed $SYMLINK_TARGET"

    print_info "Note: The source repository remains intact and can be deleted manually if needed."

    echo ""
    print_success "Uninstallation completed successfully!"
    echo ""
}

# Confirm uninstallation
echo ""
read -p "Are you sure you want to uninstall theodo-scan? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    uninstall_cli
else
    echo "Uninstallation cancelled."
    exit 0
fi

