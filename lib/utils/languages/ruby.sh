#!/usr/bin/env bash

# Ruby version detection

# Detect Ruby version
detect_ruby_version() {
    local version=""

    # Check .ruby-version
    if [ -f ".ruby-version" ]; then
        version=$(cat .ruby-version | tr -d '[:space:]')
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Fallback to installed version
    if command_exists "ruby"; then
        version=$(ruby --version 2>&1 | grep -oP 'ruby \K[0-9.]+')
        if [ -n "$version" ]; then
            print_warning "No .ruby-version found, using installed Ruby version: $version"
            echo "$version"
            return 0
        fi
    fi

    return 1
}

