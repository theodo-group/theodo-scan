#!/usr/bin/env bash

# Python version detection

# Parse a Python version string and return only major.minor version number
# Handles various formats: 3.11.2, ^3.11.2, ~3.11.0, >=3.11.0, etc.
parse_python_version() {
    local version="$1"

    if [ -z "$version" ]; then
        return 1
    fi

    # Handle caret notation: ^3.11.2 -> 3.11
    if [[ "$version" =~ \^[[:space:]]*([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        return 0
    fi

    # Handle tilde notation: ~3.11.0 -> 3.11
    if [[ "$version" =~ ~[[:space:]]*([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        return 0
    fi

    # Handle == notation: ==3.11.0 or == 3.11.0 -> 3.11
    if [[ "$version" =~ ==[[:space:]]*([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        return 0
    fi

    # Handle >= or > notation: >=3.11.0 or >= 3.11.0 or ">= 3.13, < 3.14" -> 3.11/3.13
    if [[ "$version" =~ \>=[[:space:]]*([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        return 0
    fi

    if [[ "$version" =~ \>[[:space:]]*([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        return 0
    fi

    # Remove all whitespace for remaining checks
    version=$(echo "$version" | tr -d '[:space:]')

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

# Extract and normalize version from pyproject.toml
extract_pyproject_toml_python_version() {
    if [ ! -f "pyproject.toml" ]; then
        return 1
    fi

    local python_version=""

    # Try to extract from [project] requires-python field
    # Format: requires-python = ">=3.11" or requires-python = "^3.11"
    python_version=$(grep -E '^\s*requires-python\s*=' pyproject.toml 2>/dev/null | head -1 | sed -E 's/.*requires-python\s*=\s*["\x27]([^"\x27]+)["\x27].*/\1/')

    if [ -n "$python_version" ]; then
        parse_python_version "$python_version"
        return $?
    fi

    # Try to extract from [tool.poetry.dependencies] python field
    # This requires checking if we're in the right section
    local in_poetry_deps=0
    while IFS= read -r line; do
        # Check if we're entering poetry dependencies section (with optional whitespace)
        if [[ "$line" =~ ^\[tool\.poetry\.dependencies\] ]]; then
            in_poetry_deps=1
            continue
        fi

        # Check if we're entering a new section (any line starting with [)
        if [[ "$line" =~ ^\[.*\] ]]; then
            if [ $in_poetry_deps -eq 1 ]; then
                in_poetry_deps=0
                break
            fi
        fi

        # If we're in poetry deps, look for python version
        if [ $in_poetry_deps -eq 1 ] && [[ "$line" =~ ^[[:space:]]*python[[:space:]]*= ]]; then
            # Extract content between quotes, handling both " and '
            python_version=$(echo "$line" | sed -E 's/^[[:space:]]*python[[:space:]]*=[[:space:]]*["\x27]([^"\x27]+)["\x27].*/\1/')
            if [ -n "$python_version" ]; then
                parse_python_version "$python_version"
                return $?
            fi
        fi
    done < "pyproject.toml"

    return 1
}

# Detect Python version
detect_python_version() {
    local version=""

    # Check .python-version
    if [ -f ".python-version" ]; then
        local python_version_content
        python_version_content=$(cat .python-version)
        version=$(parse_python_version "$python_version_content")
        if [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Check pyproject.toml
    version=$(extract_pyproject_toml_python_version)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi

    # Check runtime.txt (Heroku)
    if [ -f "runtime.txt" ]; then
        local runtime_version
        runtime_version=$(sed -n 's/^python-\([0-9.]*\).*/\1/p' runtime.txt 2>/dev/null | head -1)
        if [ -n "$runtime_version" ]; then
            version=$(parse_python_version "$runtime_version")
            if [ -n "$version" ]; then
                echo "$version"
                return 0
            fi
        fi
    fi

    # Fallback to installed version
    if command_exists "python3"; then
        local installed_version
        installed_version=$(python3 --version 2>&1 | sed -n 's/Python \([0-9.]*\).*/\1/p')
        if [ -n "$installed_version" ]; then
            version=$(parse_python_version "$installed_version")
            if [ -n "$version" ]; then
                print_warning "No .python-version or pyproject.toml found, using installed Python version: $version"
                echo "$version"
                return 0
            fi
        fi
    elif command_exists "python"; then
        local installed_version
        installed_version=$(python --version 2>&1 | sed -n 's/Python \([0-9.]*\).*/\1/p')
        if [ -n "$installed_version" ]; then
            version=$(parse_python_version "$installed_version")
            if [ -n "$version" ]; then
                print_warning "No .python-version or pyproject.toml found, using installed Python version: $version"
                echo "$version"
                return 0
            fi
        fi
    fi

    return 1
}

