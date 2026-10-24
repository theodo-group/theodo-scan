#!/usr/bin/env bash

# SBOM functions for theodo-scan CLI: language-specific fixes of what Trivy reports

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source language-specific SBOM scripts
source "${SCRIPT_DIR}/sbom/nodejs.sh"
source "${SCRIPT_DIR}/sbom/python.sh"
source "${SCRIPT_DIR}/sbom/java.sh"
