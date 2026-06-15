#!/usr/bin/env bash

# Configuration validation functions for theodo-scan CLI

# Validate .theodorc configuration file
# Returns 0 if valid, 1 if file doesn't exist, 2 if file exists but has missing variables
validate_theodorc_config() {
    # Check if .theodorc file exists in current directory
    if [ ! -f ".theodorc" ]; then
        return 1
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

    # If any variables are missing, show error and return
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing required configuration variables in .theodorc:"
        for var in "${missing_vars[@]}"; do
            print_error "  - $var"
        done
        print_info "Please edit .theodorc and set all required values."
        return 2
    fi

    # Configuration is valid
    return 0
}

