#!/usr/bin/env bash

# Main utils file - sources all utility modules
# This file is kept for backward compatibility

# Get the directory where this script is located
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all utility modules
source "$UTILS_DIR/output.sh"
source "$UTILS_DIR/dependencies.sh"
source "$UTILS_DIR/config.sh"
source "$UTILS_DIR/language-detection.sh"
