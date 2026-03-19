#!/usr/bin/env bash

# PHP version detection

# Parse a PHP version string and return only major.minor version number
# Handles various formats: 8.1.2, ^8.1.2, ~8.1.0, >=8.1.0, etc.
parse_php_version() {
    local version="$1"

    if [ -z "$version" ]; then
        return 1
    fi

    # Remove whitespace
    version=$(echo "$version" | tr -d '[:space:]')

    # Handle caret notation: ^8.1.2 -> 8.1
    if [[ "$version" =~ ^\^([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        return 0
    fi

    # Handle tilde notation: ~8.1.0 -> 8.1
    if [[ "$version" =~ ^~([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        return 0
    fi

    # Handle >= or > notation: >=8.1.0 -> 8.1
    if [[ "$version" =~ ^\>=?([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        return 0
    fi

    # If it's a full version number (x.y.z), return major.minor
    if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        return 0
    fi

    # If it's already major.minor format, return as is
    if [[ "$version" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        return 0
    fi

    # If it's just a major version, try to add .0
    if [[ "$version" =~ ^([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}.0"
        return 0
    fi

    return 1
}

# Extract and normalize version from composer.json require.php
extract_composer_json_php_version() {
    if [ ! -f "composer.json" ]; then
        return 1
    fi

    # Check if jq is available
    if ! command_exists "jq"; then
        return 1
    fi

    local php_version
    php_version=$(jq -r '.require.php // empty' composer.json 2>/dev/null)

    if [ -z "$php_version" ] || [ "$php_version" = "null" ]; then
        return 1
    fi

    # Parse the version and return major.minor
    parse_php_version "$php_version"
    return $?
}

# Detect PHP version
detect_php_version() {
    local version=""

    # Check .php-version
    if [ -f ".php-version" ]; then
        local php_version_content
        php_version_content=$(cat .php-version)
        version=$(parse_php_version "$php_version_content")
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Check composer.json require.php
    version=$(extract_composer_json_php_version)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi

    # Fallback to installed version
    if command_exists "php"; then
        local installed_version
        installed_version=$(php --version 2>&1 | sed -n 's/.*PHP \([0-9.]*\).*/\1/p' | head -1)
        if [ -n "$installed_version" ]; then
            version=$(parse_php_version "$installed_version")
            if [ -n "$version" ]; then
                print_warning "No .php-version found, using installed PHP version: $version"
                echo "$version"
                return 0
            fi
        fi
    fi

    return 1
}

