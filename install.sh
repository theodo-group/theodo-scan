#!/usr/bin/env bash

# Installation script for theodo-scan CLI
# Supports Linux and macOS

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

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

# Check if running with sufficient permissions
check_permissions() {
    if [ -w "$INSTALL_DIR" ]; then
        return 0
    else
        return 1
    fi
}

# Main installation function
install_cli() {
    local os=$(detect_os)

    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Theodo Scan CLI - Installation      ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Validate OS
    if [ "$os" == "unknown" ]; then
        print_error "Unsupported operating system: $OSTYPE"
        print_info "This installer only supports Linux and macOS."
        exit 1
    fi

    print_info "Detected OS: $os"
    echo ""

    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Default installation directory
    INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

    print_info "Installation directory: $INSTALL_DIR"
    print_info "Source directory: $SCRIPT_DIR"
    echo ""

    # Check permissions
    if ! check_permissions; then
        print_warning "No write permission to $INSTALL_DIR"
        print_info "Attempting to install with sudo..."
        USE_SUDO=true
    else
        USE_SUDO=false
    fi

    # Verify the main CLI script exists
    if [ ! -f "$SCRIPT_DIR/bin/theodo-scan" ]; then
        print_error "Source file not found: $SCRIPT_DIR/bin/theodo-scan"
        exit 1
    fi

    # Create symlink to the CLI executable
    SYMLINK_TARGET="$INSTALL_DIR/theodo-scan"

    # Remove existing symlink or file if it exists
    if [ -e "$SYMLINK_TARGET" ] || [ -L "$SYMLINK_TARGET" ]; then
        print_info "Removing existing installation..."
        if [ "$USE_SUDO" = true ]; then
            sudo rm -f "$SYMLINK_TARGET"
        else
            rm -f "$SYMLINK_TARGET"
        fi
    fi

    # Create the symlink
    if [ "$USE_SUDO" = true ]; then
        sudo ln -s "$SCRIPT_DIR/bin/theodo-scan" "$SYMLINK_TARGET"
    else
        ln -s "$SCRIPT_DIR/bin/theodo-scan" "$SYMLINK_TARGET"
    fi

    print_success "Created symlink: $SYMLINK_TARGET -> $SCRIPT_DIR/bin/theodo-scan"

    echo ""
    print_success "Installation completed successfully!"
    echo ""
    print_info "You can now use the 'theodo-scan' command:"
    echo ""
    theodo-scan help
    echo ""
    print_info "To update theodo-scan, simply run 'git pull' in:"
    echo "    $SCRIPT_DIR"
    echo ""

    # Check if install directory is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        print_warning "$INSTALL_DIR is not in your PATH"
        print_info "Add it to your PATH by adding this line to your ~/.bashrc or ~/.zshrc:"
        echo ""
        echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
        echo ""
    fi
}

# Run installation
install_cli

