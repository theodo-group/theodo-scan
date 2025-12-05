#!/usr/bin/env bash

# Utility functions for theodo-scan CLI

# Colors for output
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'

# Print colored output
print_error() {
    echo -e "${COLOR_RED}Error: $1${COLOR_RESET}" >&2
}

print_success() {
    echo -e "${COLOR_GREEN}✓ $1${COLOR_RESET}"
}

print_warning() {
    echo -e "${COLOR_YELLOW}Warning: $1${COLOR_RESET}"
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ $1${COLOR_RESET}"
}

print_header() {
    echo -e "${COLOR_CYAN}$1${COLOR_RESET}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate required dependencies
check_dependencies() {
    local deps=("$@")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing[*]}"
        return 1
    fi
    return 0
}

# Validate .theodorc configuration file
validate_theodorc_config() {
    # Check if .theodorc file exists in current directory
    if [ ! -f ".theodorc" ]; then
        print_error "Configuration file .theodorc not found in current directory."
        print_info "Please run 'theodo-scan init' first to create a configuration file."
        exit 1
    fi

    # Source the configuration file
    source ".theodorc"

    # Validate required variables are set and not empty
    local missing_vars=()

    if [ -z "${THEODO_SCAN_ORG:-}" ]; then
        missing_vars+=("THEODO_SCAN_ORG")
    fi

    if [ -z "${THEODO_SCAN_PROJECT:-}" ]; then
        missing_vars+=("THEODO_SCAN_PROJECT")
    fi

    if [ -z "${THEODO_SCAN_COMPONENT:-}" ]; then
        missing_vars+=("THEODO_SCAN_COMPONENT")
    fi

    # If any variables are missing, show error and exit
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing required configuration variables in .theodorc:"
        for var in "${missing_vars[@]}"; do
            print_error "  - $var"
        done
        print_info "Please edit .theodorc and set all required values."
        exit 1
    fi

    # Configuration is valid
    return 0
}

# Check dependencies required for scan command
check_scan_dependencies() {
    local missing_deps=()

    # Check for trivy
    if ! command_exists "trivy"; then
        missing_deps+=("trivy")
    fi

    # Check for jq
    if ! command_exists "jq"; then
        missing_deps+=("jq")
    fi

    # If dependencies are missing, show error with installation instructions
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies for scan command:"
        echo ""

        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                trivy)
                    print_error "  ✗ trivy - Vulnerability scanner"
                    print_info "    Install: https://trivy.dev/docs/latest/getting-started/installation/"
                    echo ""
                    ;;
                jq)
                    print_error "  ✗ jq - JSON processor"
                    print_info "    Install: https://jqlang.github.io/jq/download/"
                    echo ""
                    ;;
            esac
        done

        print_info "Please install the missing dependencies and try again."
        exit 1
    fi

    # All dependencies are available
    return 0
}

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

# Detect version for a specific language
detect_language_version() {
    local language="$1"
    local version=""

    case "$language" in
        nodejs)
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
            ;;

        python)
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
            ;;

        ruby)
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
            ;;

        java)
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
            ;;

        go)
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
            ;;

        php)
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
            ;;
    esac

    return 1
}

# Detect all programming languages in the project
detect_project_languages() {
    local languages_json="[]"

    # Detect Node.js
    if [ -f ".nvmrc" ] || [ -f "package.json" ] || [ -d "node_modules" ] || [ -f ".node-version" ]; then
        local version
        version=$(detect_language_version "nodejs")
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
        version=$(detect_language_version "python")
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

    # Detect Ruby
    if [ -f ".ruby-version" ] || [ -f "Gemfile" ] || [ -n "$(find . -maxdepth 2 -name '*.rb' 2>/dev/null | head -1)" ]; then
        local version
        version=$(detect_language_version "ruby")
        if [ -n "$version" ]; then
            print_info "  ✓ Detected Ruby: $version" >&2
            languages_json=$(echo "$languages_json" | jq --arg version "$version" \
                '. += [{
                    "type": "framework",
                    "bom-ref": ("lang-ruby-" + $version),
                    "name": "ruby",
                    "version": $version,
                    "purl": ("pkg:generic/ruby@" + $version)
                }]')
        fi
    fi

    # Detect Java
    if [ -f ".java-version" ] || [ -f "pom.xml" ] || [ -f "build.gradle" ] || [ -n "$(find . -maxdepth 2 -name '*.java' 2>/dev/null | head -1)" ]; then
        local version
        version=$(detect_language_version "java")
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

    # Detect Go
    if [ -f "go.mod" ] || [ -f ".go-version" ] || [ -n "$(find . -maxdepth 2 -name '*.go' 2>/dev/null | head -1)" ]; then
        local version
        version=$(detect_language_version "go")
        if [ -n "$version" ]; then
            print_info "  ✓ Detected Go: $version" >&2
            languages_json=$(echo "$languages_json" | jq --arg version "$version" \
                '. += [{
                    "type": "framework",
                    "bom-ref": ("lang-go-" + $version),
                    "name": "go",
                    "version": $version,
                    "purl": ("pkg:generic/go@" + $version)
                }]')
        fi
    fi

    # Detect PHP
    if [ -f ".php-version" ] || [ -f "composer.json" ] || [ -n "$(find . -maxdepth 2 -name '*.php' 2>/dev/null | head -1)" ]; then
        local version
        version=$(detect_language_version "php")
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

