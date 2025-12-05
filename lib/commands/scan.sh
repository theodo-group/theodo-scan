#!/usr/bin/env bash

# Scan command implementation

cmd_scan() {
    local show_help=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run 'theodo-scan scan --help' for usage information."
                exit 1
                ;;
        esac
    done

    # Show help if requested
    if [ "$show_help" = true ]; then
        cat << EOF
Usage: theodo-scan scan [options]

Run a security scan using Trivy and generate a CycloneDX SBOM (Software Bill of Materials).

This command:
  1. Scans the current directory for vulnerabilities and dependencies
  2. Generates an SBOM in CycloneDX format at .theodo/sbom.json
  3. Updates the component name with your project identification

Options:
    -h, --help          Show this help message

Examples:
    theodo-scan scan

Note: Requires .theodorc file. Run 'theodo-scan init' first.
Required dependencies: trivy, jq

EOF
        exit 0
    fi

    # Validate and load configuration
    validate_theodorc_config

    # Check required dependencies
    check_scan_dependencies

    # Display scan header
    print_header "🔍 Theodo Scan - Security Scan"
    echo ""

    # Define output paths
    SBOM_DIR=".theodo"
    SBOM_FILE="${SBOM_DIR}/sbom.json"

    # Create .theodo directory if it doesn't exist
    if [ ! -d "$SBOM_DIR" ]; then
        mkdir -p "$SBOM_DIR"
        print_info "Created directory: $SBOM_DIR"
    fi

    # Run Trivy scan
    print_info "Running Trivy scan..."
    echo ""

    if ! trivy fs --format cyclonedx -o "${SBOM_FILE}" .; then
        print_error "Trivy scan failed"
        exit 1
    fi

    echo ""

    # Modify SBOM component name and add metadata properties
    COMPONENT_NAME="${THEODO_SCAN_ORG}-${THEODO_SCAN_PROJECT}-${THEODO_SCAN_COMPONENT}"
    print_info "Updating SBOM metadata..."
    print_info "  - Component name: $COMPONENT_NAME"
    print_info "  - Organization: $THEODO_SCAN_ORG"
    print_info "  - Project: $THEODO_SCAN_PROJECT"
    print_info "  - Component: $THEODO_SCAN_COMPONENT"

    if ! jq --arg name "${COMPONENT_NAME}" \
            --arg org "${THEODO_SCAN_ORG}" \
            --arg project "${THEODO_SCAN_PROJECT}" \
            --arg component "${THEODO_SCAN_COMPONENT}" '
        .metadata.component.name = $name |
        .metadata.properties = (.metadata.properties // []) |
        .metadata.properties += [
            {"name": "theodo:org", "value": $org},
            {"name": "theodo:project", "value": $project},
            {"name": "theodo:component", "value": $component}
        ]
    ' "${SBOM_FILE}" > "${SBOM_FILE}.tmp"; then
        print_error "Failed to update SBOM metadata"
        exit 1
    fi

    mv "${SBOM_FILE}.tmp" "${SBOM_FILE}"

    # Display success message
    echo ""
    print_success "SBOM generated successfully!"
    print_info "SBOM saved to: ${SBOM_FILE}"
    echo ""
}

