#!/usr/bin/env bash

# Language detection functions for theodo-scan CLI

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source language-specific detection scripts
source "${SCRIPT_DIR}/languages/nodejs.sh"
source "${SCRIPT_DIR}/languages/python.sh"
source "${SCRIPT_DIR}/languages/java.sh"
source "${SCRIPT_DIR}/languages/php.sh"

# Detect all programming languages in the project
detect_project_languages() {
    local languages_json="[]"

    # Detect Node.js
    if [ -f ".nvmrc" ] || [ -f "package.json" ] || [ -d "node_modules" ] || [ -f ".node-version" ]; then
        local version
        version=$(detect_nodejs_version)
        if [ -n "$version" ]; then
            print_info "  ✓ Detected Node.js: $version" >&2
            languages_json=$(echo "$languages_json" | jq --arg version "$version" \
                '. += [{
                    "type": "framework",
                    "bom-ref": ("lang-nodejs-" + $version),
                    "name": "nodejs",
                    "version": $version,
                    "purl": ("pkg:generic/nodejs@" + $version)
                }]')
        fi
    fi

    # Detect Python
    if [ -f ".python-version" ] || [ -f "requirements.txt" ] || [ -f "Pipfile" ] || [ -f "pyproject.toml" ] || [ -n "$(find . -maxdepth 2 -name '*.py' 2>/dev/null | head -1)" ]; then
        local version
        version=$(detect_python_version)
        if [ -n "$version" ]; then
            print_info "  ✓ Detected Python: $version" >&2
            languages_json=$(echo "$languages_json" | jq --arg version "$version" \
                '. += [{
                    "type": "framework",
                    "bom-ref": ("lang-python-" + $version),
                    "name": "python",
                    "version": $version,
                    "purl": ("pkg:generic/python@" + $version)
                }]')
        fi
    fi

    # Detect Java
    if [ -f ".java-version" ] || [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -n "$(find . -maxdepth 2 -name '*.java' 2>/dev/null | head -1)" ]; then
        local version
        version=$(detect_java_version)
        if [ -n "$version" ]; then
            print_info "  ✓ Detected Java: $version" >&2
            languages_json=$(echo "$languages_json" | jq --arg version "$version" \
                '. += [{
                    "type": "framework",
                    "bom-ref": ("lang-java-" + $version),
                    "name": "java",
                    "version": $version,
                    "purl": ("pkg:generic/java@" + $version)
                }]')
        fi
    fi

    # Detect PHP
    if [ -f ".php-version" ] || [ -f "composer.json" ] || [ -n "$(find . -maxdepth 2 -name '*.php' 2>/dev/null | head -1)" ]; then
        local version
        version=$(detect_php_version)
        if [ -n "$version" ]; then
            print_info "  ✓ Detected PHP: $version" >&2
            languages_json=$(echo "$languages_json" | jq --arg version "$version" \
                '. += [{
                    "type": "framework",
                    "bom-ref": ("lang-php-" + $version),
                    "name": "php",
                    "version": $version,
                    "purl": ("pkg:generic/php@" + $version)
                }]')
        fi
    fi

    echo "$languages_json"
}

