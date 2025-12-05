#!/usr/bin/env bash

# Node.js version detection

# Resolve .nvmrc version aliases to actual versions
resolve_nvmrc_version() {
    if [ ! -f ".nvmrc" ]; then
        return 1
    fi

    local nvmrc_content
    nvmrc_content=$(cat .nvmrc | tr -d '[:space:]')

    # LTS version mapping (as of December 2025)
    case "$nvmrc_content" in
        lts/jod)
            echo "v22.21.1"
            return 0
            ;;
        lts/iron)
            echo "v20.18.1"
            return 0
            ;;
        lts/hydrogen)
            echo "v18.20.5"
            return 0
            ;;
        lts/gallium)
            echo "v16.20.2"
            return 0
            ;;
        lts/*|lts)
            # Latest LTS defaults to jod
            echo "v22.21.1"
            return 0
            ;;
        *)
            # If it's a version number, normalize it
            if [[ "$nvmrc_content" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                # Add v prefix if not present
                if [[ "$nvmrc_content" =~ ^v ]]; then
                    echo "$nvmrc_content"
                else
                    echo "v${nvmrc_content}"
                fi
                return 0
            fi
            # If it's just major.minor, return as is with v prefix
            if [[ "$nvmrc_content" =~ ^v?[0-9]+\.[0-9]+$ ]] || [[ "$nvmrc_content" =~ ^v?[0-9]+$ ]]; then
                if [[ "$nvmrc_content" =~ ^v ]]; then
                    echo "$nvmrc_content"
                else
                    echo "v${nvmrc_content}"
                fi
                return 0
            fi
            return 1
            ;;
    esac
}

# Detect Node.js version
detect_nodejs_version() {
    local version=""

    # Check .nvmrc first
    if [ -f ".nvmrc" ]; then
        version=$(resolve_nvmrc_version)
        if [ -n "$version" ]; then
            # Remove v prefix for consistency
            version="${version#v}"
            echo "$version"
            return 0
        fi
    fi

    # Check .node-version
    if [ -f ".node-version" ]; then
        version=$(cat .node-version | tr -d '[:space:]' | sed 's/^v//')
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Fallback to installed version
    if command_exists "node"; then
        version=$(node --version 2>/dev/null | sed 's/^v//')
        if [ -n "$version" ]; then
            print_warning "No .nvmrc or .node-version found, using installed Node.js version: $version"
            echo "$version"
            return 0
        fi
    fi

    return 1
}

