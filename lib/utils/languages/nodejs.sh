#!/usr/bin/env bash

# Node.js version detection

# Parse a Node.js version string and return only the major version number
# Handles various formats: v22.1.2, 22.1.2, ^22.1.2, ~22.1.2, >=22.0.0, etc.
parse_node_version() {
    local version="$1"

    if [ -z "$version" ]; then
        return 1
    fi

    # Remove whitespace
    version=$(echo "$version" | tr -d '[:space:]')

    # Handle caret notation: ^22.1.2 -> 22
    if [[ "$version" =~ ^\^([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Handle tilde notation: ~22.1.2 -> 22
    if [[ "$version" =~ ^~([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Handle >= or > notation: >=22.0.0 -> 22
    if [[ "$version" =~ ^\>=?([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Remove v prefix if present
    version="${version#v}"

    # Extract major version from x.y.z, x.y, or x
    if [[ "$version" =~ ^([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

# Resolve .nvmrc version aliases to actual versions (returns major only)
resolve_nvmrc_version() {
    if [ ! -f ".nvmrc" ]; then
        return 1
    fi

    local nvmrc_content
    nvmrc_content=$(cat .nvmrc | tr -d '[:space:]')

    # LTS version mapping (as of December 2025)
    case "$nvmrc_content" in
        lts/krypton)
            echo "24"
            return 0
            ;;
        lts/jod)
            echo "22"
            return 0
            ;;
        lts/iron)
            echo "20"
            return 0
            ;;
        lts/hydrogen)
            echo "18"
            return 0
            ;;
        lts/gallium)
            echo "16"
            return 0
            ;;
        *)
            # For any version number format, parse and return major
            parse_node_version "$nvmrc_content"
            return $?
            ;;
    esac
}

# Extract and normalize version from package.json engines.node
extract_package_json_node_version() {
    if [ ! -f "package.json" ]; then
        return 1
    fi

    # Check if jq is available
    if ! command_exists "jq"; then
        return 1
    fi

    local node_version
    node_version=$(jq -r '.engines.node // empty' package.json 2>/dev/null)

    if [ -z "$node_version" ] || [ "$node_version" = "null" ]; then
        return 1
    fi

    # Parse the version and return major
    parse_node_version "$node_version"
    return $?
}

# Detect Node.js version
detect_nodejs_version() {
    local version=""

    # Check .nvmrc first
    if [ -f ".nvmrc" ]; then
        version=$(resolve_nvmrc_version)
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Check package.json engines.node
    version=$(extract_package_json_node_version)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi

    # Check .node-version
    if [ -f ".node-version" ]; then
        local node_version_content
        node_version_content=$(cat .node-version)
        version=$(parse_node_version "$node_version_content")
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Fallback to installed version
    if command_exists "node"; then
        local installed_version
        installed_version=$(node --version 2>/dev/null)
        if [ -n "$installed_version" ]; then
            version=$(parse_node_version "$installed_version")
            if [ -n "$version" ]; then
                print_warning "No .nvmrc or .node-version found, using installed Node.js version: $version"
                echo "$version"
                return 0
            fi
        fi
    fi

    return 1
}

