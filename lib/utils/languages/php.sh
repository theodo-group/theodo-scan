#!/usr/bin/env bash

# PHP version detection

# Detect PHP version
detect_php_version() {
    local version=""

    # Check .php-version
    if [ -f ".php-version" ]; then
        version=$(cat .php-version | tr -d '[:space:]')
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Fallback to installed version
    if command_exists "php"; then
        version=$(php --version 2>&1 | grep -oP 'PHP \K[0-9.]+' | head -1)
        if [ -n "$version" ]; then
            print_warning "No .php-version found, using installed PHP version: $version"
            echo "$version"
            return 0
        fi
    fi

    return 1
}

