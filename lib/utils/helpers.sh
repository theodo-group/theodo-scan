#!/usr/bin/env bash

# Utility functions for theodo-scan CLI

# Colors for output
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'

# Print colored output
print_error() {
    echo -e "${COLOR_RED}Error: $1${COLOR_RESET}" >&2
}

print_success() {
    echo -e "${COLOR_GREEN}✓ $1${COLOR_RESET}"
}

print_warning() {
    echo -e "${COLOR_YELLOW}Warning: $1${COLOR_RESET}"
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ $1${COLOR_RESET}"
}

print_header() {
    echo -e "${COLOR_CYAN}$1${COLOR_RESET}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate required dependencies
check_dependencies() {
    local deps=("$@")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing[*]}"
        return 1
    fi
    return 0
}

# Validate .theodorc configuration file
validate_theodorc_config() {
    # Check if .theodorc file exists in current directory
    if [ ! -f ".theodorc" ]; then
        print_error "Configuration file .theodorc not found in current directory."
        print_info "Please run 'theodo-scan init' first to create a configuration file."
        exit 1
    fi

    # Source the configuration file
    source ".theodorc"

    # Validate required variables are set and not empty
    local missing_vars=()

    if [ -z "${THEODO_SCAN_ORG:-}" ]; then
        missing_vars+=("THEODO_SCAN_ORG")
    fi

    if [ -z "${THEODO_SCAN_PROJECT:-}" ]; then
        missing_vars+=("THEODO_SCAN_PROJECT")
    fi

    if [ -z "${THEODO_SCAN_COMPONENT:-}" ]; then
        missing_vars+=("THEODO_SCAN_COMPONENT")
    fi

    # If any variables are missing, show error and exit
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing required configuration variables in .theodorc:"
        for var in "${missing_vars[@]}"; do
            print_error "  - $var"
        done
        print_info "Please edit .theodorc and set all required values."
        exit 1
    fi

    # Configuration is valid
    return 0
}

# Check dependencies required for scan command
check_scan_dependencies() {
    local missing_deps=()

    # Check for trivy
    if ! command_exists "trivy"; then
        missing_deps+=("trivy")
    fi

    # Check for jq
    if ! command_exists "jq"; then
        missing_deps+=("jq")
    fi

    # If dependencies are missing, show error with installation instructions
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies for scan command:"
        echo ""

        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                trivy)
                    print_error "  ✗ trivy - Vulnerability scanner"
                    print_info "    Install: https://trivy.dev/docs/latest/getting-started/installation/"
                    echo ""
                    ;;
                jq)
                    print_error "  ✗ jq - JSON processor"
                    print_info "    Install: https://jqlang.github.io/jq/download/"
                    echo ""
                    ;;
            esac
        done

        print_info "Please install the missing dependencies and try again."
        exit 1
    fi

    # All dependencies are available
    return 0
}

