#!/usr/bin/env bash

# Go version detection

# Detect Go version
detect_go_version() {
    local version=""

    # Check go.mod
    if [ -f "go.mod" ]; then
        version=$(grep -oP '^go \K[0-9.]+' go.mod 2>/dev/null)
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Check .go-version
    if [ -f ".go-version" ]; then
        version=$(cat .go-version | tr -d '[:space:]')
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Fallback to installed version
    if command_exists "go"; then
        version=$(go version 2>&1 | grep -oP 'go\K[0-9.]+')
        if [ -n "$version" ]; then
            print_warning "No go.mod or .go-version found, using installed Go version: $version"
            echo "$version"
            return 0
        fi
    fi

    return 1
}

