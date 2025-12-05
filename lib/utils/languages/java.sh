#!/usr/bin/env bash

# Java version detection

# Detect Java version
detect_java_version() {
    local version=""

    # Check .java-version
    if [ -f ".java-version" ]; then
        version=$(cat .java-version | tr -d '[:space:]')
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Fallback to installed version
    if command_exists "java"; then
        version=$(java -version 2>&1 | grep -oP 'version "\K[0-9.]+' | head -1)
        if [ -n "$version" ]; then
            print_warning "No .java-version found, using installed Java version: $version"
            echo "$version"
            return 0
        fi
    fi

    return 1
}

