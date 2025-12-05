#!/usr/bin/env bash

# Output utility functions for theodo-scan CLI

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

