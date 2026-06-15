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
  2. Detects programming languages and runtimes (Node.js, Python, Ruby, Java, Go, PHP)
  3. Generates an SBOM in CycloneDX format at .theodo/sbom.json
  4. Updates the component name with your project identification
  5. Adds detected languages as framework components in the SBOM
  6. Flags dev-only dependencies with a "theodo:dev" property

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
    if ! validate_theodorc_config; then
        # Config validation failed - run init
        print_warning "Configuration file is missing or invalid."
        print_info "Running init to create/fix configuration..."
        echo ""

        COMMANDS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        source "$COMMANDS_DIR/init.sh"
        cmd_init

        echo ""
        print_info "Continuing with scan..."
        echo ""

        # Validate again after init
        if ! validate_theodorc_config; then
            print_error "Configuration is still invalid after init."
            exit 1
        fi
    fi

    # Check required dependencies
    check_scan_dependencies

    # Display scan header
    print_header "🔍 Theodo Scan - Security Scan"
    echo ""

    # Define output paths
    SBOM_DIR=".theodo"
    SBOM_FILE="${SBOM_DIR}/sbom.json"
    SBOM_PROD_FILE="${SBOM_DIR}/sbom.prod.json"

    # Create .theodo directory if it doesn't exist
    if [ ! -d "$SBOM_DIR" ]; then
        mkdir -p "$SBOM_DIR"
        print_info "Created directory: $SBOM_DIR"
    fi

    # Run Trivy scan (production dependencies only, used to identify dev-only deps)
    print_info "Running Trivy scan (production dependencies)..."
    echo ""

    if ! trivy fs --format cyclonedx -o "${SBOM_PROD_FILE}" .; then
        print_error "Trivy scan failed (production dependencies)"
        exit 1
    fi

    echo ""

    # Run Trivy scan (all dependencies including dev)
    print_info "Running Trivy scan (all dependencies including dev)..."
    echo ""

    if ! trivy fs --include-dev-deps --format cyclonedx -o "${SBOM_FILE}" .; then
        print_error "Trivy scan failed"
        exit 1
    fi

    echo ""

    # Flag dev-only components (present in full SBOM but not in production SBOM)
    print_info "Flagging dev-only dependencies..."

    PROD_REFS=$(jq '[.components[]?."bom-ref"]' "${SBOM_PROD_FILE}")

    if ! jq --argjson prod "${PROD_REFS}" '
        .components |= map(
            if (."bom-ref" as $r | $prod | index($r)) then
                .
            else
                .properties = ((.properties // []) + [{"name": "theodo:dev", "value": "true"}])
            end
        )
    ' "${SBOM_FILE}" > "${SBOM_FILE}.tmp"; then
        print_error "Failed to flag dev-only dependencies"
        exit 1
    fi

    mv "${SBOM_FILE}.tmp" "${SBOM_FILE}"
    rm -f "${SBOM_PROD_FILE}"

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

    # Detect and add programming languages as framework components
    echo ""
    print_info "Detecting programming languages..."

    DETECTED_LANGUAGES=$(detect_project_languages)

    if [ -n "$DETECTED_LANGUAGES" ] && [ "$DETECTED_LANGUAGES" != "[]" ]; then
        print_info "Adding detected languages to SBOM..."

        if ! jq --argjson languages "${DETECTED_LANGUAGES}" '
            # Add language components to the components array
            .components = ((.components // []) + $languages) |

            # Add language bom-refs to main component dependencies
            .dependencies[0].dependsOn = (
                (.dependencies[0].dependsOn // []) +
                ($languages | map(."bom-ref"))
            )
        ' "${SBOM_FILE}" > "${SBOM_FILE}.tmp"; then
            print_error "Failed to add language components to SBOM"
            exit 1
        fi

        mv "${SBOM_FILE}.tmp" "${SBOM_FILE}"
        print_success "Language detection complete"
    else
        print_info "No languages detected"
    fi

    # Display success message
    echo ""
    print_success "SBOM generated successfully!"
    print_info "SBOM saved to: ${SBOM_FILE}"
    echo ""
}

