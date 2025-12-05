#!/usr/bin/env bash

# Python version detection

# Detect Python version
detect_python_version() {
    local version=""

    # Check .python-version
    if [ -f ".python-version" ]; then
        version=$(cat .python-version | tr -d '[:space:]')
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Check runtime.txt (Heroku)
    if [ -f "runtime.txt" ]; then
        version=$(grep -oP 'python-\K[0-9.]+' runtime.txt 2>/dev/null)
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Fallback to installed version
    if command_exists "python3"; then
        version=$(python3 --version 2>&1 | grep -oP 'Python \K[0-9.]+')
        if [ -n "$version" ]; then
            print_warning "No .python-version found, using installed Python version: $version"
            echo "$version"
            return 0
        fi
    elif command_exists "python"; then
        version=$(python --version 2>&1 | grep -oP 'Python \K[0-9.]+')
        if [ -n "$version" ]; then
            print_warning "No .python-version found, using installed Python version: $version"
            echo "$version"
            return 0
        fi
    fi

    return 1
}

