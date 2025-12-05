#!/usr/bin/env bash

# Dependency checking functions for theodo-scan CLI

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

