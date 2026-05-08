#!/usr/bin/env bash

# Upload command implementation

cmd_upload() {
    local show_help=false
    local bucket=""
    local sbom_file=".theodo/sbom.json"
    local aws_profile=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help=true
                shift
                ;;
            -b|--bucket)
                bucket="$2"
                shift 2
                ;;
            -f|--file)
                sbom_file="$2"
                shift 2
                ;;
            -p|--profile)
                aws_profile="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run 'theodo-scan upload --help' for usage information."
                exit 1
                ;;
        esac
    done

    # Show help if requested
    if [ "$show_help" = true ]; then
        cat << EOF
Usage: theodo-scan upload [options]

Upload an SBOM file to an S3 bucket.

The SBOM will be uploaded to: s3://<bucket>/sboms/<org>-<project>-<component>/theodo-scan-sbom.json
where <org>, <project>, and <component> are extracted from the SBOM's metadata.properties.

The bucket name can be specified via --bucket flag or configured in .theodorc
as THEODO_SCAN_BUCKET_NAME.

For local runs, an AWS CLI profile is required. It can be specified via --profile
flag or configured in .theodorc as THEODO_SCAN_LOCAL_AWS_PROFILE.

In CI (when the CI environment variable is set), the --profile flag is ignored
and the default AWS credential chain is used. Configure your CI to assume an
IAM role via OIDC (recommended) or expose AWS credentials as environment
variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN).

Options:
    -b, --bucket <name>     S3 bucket name (overrides .theodorc)
    -f, --file <path>       Path to SBOM file (default: .theodo/sbom.json)
    -p, --profile <name>    AWS CLI profile to use (local only; overrides .theodorc)
    -h, --help              Show this help message

Examples:
    theodo-scan upload
    theodo-scan upload --bucket my-bucket
    theodo-scan upload --bucket my-bucket --profile my-aws-profile
    theodo-scan upload --bucket my-bucket --file ./custom-sbom.json

Required dependencies: aws (AWS CLI)

EOF
        exit 0
    fi

    # Check required dependencies
    check_upload_dependencies

    # Load config from .theodorc if needed
    if [ -z "$bucket" ] || [ -z "$aws_profile" ]; then
        if [ -f ".theodorc" ]; then
            source ".theodorc"
            if [ -z "$bucket" ]; then
                bucket="${THEODO_SCAN_BUCKET_NAME:-}"
            fi
            if [ -z "$aws_profile" ]; then
                aws_profile="${THEODO_SCAN_LOCAL_AWS_PROFILE:-}"
            fi
        fi
    fi

    # Validate bucket parameter
    if [ -z "$bucket" ]; then
        print_error "Missing required bucket name."
        print_info "Either specify --bucket flag or set THEODO_SCAN_BUCKET_NAME in .theodorc"
        exit 1
    fi

    # In CI, skip the AWS profile entirely and rely on the default credential chain
    # (OIDC-assumed role or AWS_* environment variables).
    if [ -n "${CI:-}" ]; then
        if [ -n "$aws_profile" ]; then
            print_info "CI environment detected — ignoring AWS profile '$aws_profile' and using default credential chain."
        fi
        aws_profile=""
    elif [ -z "$aws_profile" ]; then
        print_error "Missing required AWS profile."
        print_info "Either specify --profile flag or set THEODO_SCAN_LOCAL_AWS_PROFILE in .theodorc"
        print_info "(In CI, set the CI environment variable and configure AWS credentials via OIDC or env vars.)"
        exit 1
    fi

    # Validate SBOM file exists
    if [ ! -f "$sbom_file" ]; then
        print_error "SBOM file not found: $sbom_file"
        print_info "Run 'theodo-scan scan' first to generate an SBOM, or specify a different file with --file."
        exit 1
    fi

    # Display upload header
    print_header "📤 Theodo Scan - Upload SBOM"
    echo ""

    # Extract project name from SBOM metadata
    print_info "Reading SBOM metadata..."

    local org project component
    org=$(jq -r '.metadata.properties[] | select(.name == "theodo:org") | .value' "$sbom_file" 2>/dev/null)
    project=$(jq -r '.metadata.properties[] | select(.name == "theodo:project") | .value' "$sbom_file" 2>/dev/null)
    component=$(jq -r '.metadata.properties[] | select(.name == "theodo:component") | .value' "$sbom_file" 2>/dev/null)

    if [ -z "$org" ] || [ "$org" = "null" ]; then
        print_error "Could not extract 'theodo:org' from SBOM metadata"
        print_info "Ensure the SBOM was generated with 'theodo-scan scan' and contains the required metadata."
        exit 1
    fi

    if [ -z "$project" ] || [ "$project" = "null" ]; then
        print_error "Could not extract 'theodo:project' from SBOM metadata"
        print_info "Ensure the SBOM was generated with 'theodo-scan scan' and contains the required metadata."
        exit 1
    fi

    if [ -z "$component" ] || [ "$component" = "null" ]; then
        print_error "Could not extract 'theodo:component' from SBOM metadata"
        print_info "Ensure the SBOM was generated with 'theodo-scan scan' and contains the required metadata."
        exit 1
    fi

    print_info "  - Org: $org"
    print_info "  - Project: $project"
    print_info "  - Component: $component"

    # Build S3 destination path
    local s3_path="s3://${bucket}/sboms/${org}-${project}-${component}/theodo-scan-sbom.json"

    print_info "  - Destination: $s3_path"
    if [ -n "$aws_profile" ]; then
        print_info "  - AWS Profile: $aws_profile"
    else
        print_info "  - AWS credentials: default chain (CI mode)"
    fi
    echo ""

    # Build AWS CLI args (omit --profile in CI / when not configured)
    local aws_args=()
    if [ -n "$aws_profile" ]; then
        aws_args+=("--profile" "$aws_profile")
    fi

    # Upload to S3
    print_info "Uploading SBOM to S3..."

    local upload_output
    local upload_exit_code=0
    upload_output=$(aws "${aws_args[@]}" s3 cp "$sbom_file" "$s3_path" 2>&1) || upload_exit_code=$?

    # If upload failed due to expired SSO token, attempt auto-login and retry (local only).
    if [[ $upload_exit_code -ne 0 ]] && [ -n "$aws_profile" ] && echo "$upload_output" | grep -q "Token has expired and refresh failed\|Error when retrieving token from sso\|The SSO session associated with this profile has expired"; then
        print_warning "SSO token expired. Attempting login with profile '$aws_profile'..."
        if ! aws sso login --profile "$aws_profile"; then
            print_error "SSO login failed"
            exit 1
        fi
        print_info "Retrying upload..."
        if ! aws "${aws_args[@]}" s3 cp "$sbom_file" "$s3_path"; then
            print_error "Failed to upload SBOM to S3"
            exit 1
        fi
    elif [[ $upload_exit_code -ne 0 ]]; then
        echo "$upload_output" >&2
        print_error "Failed to upload SBOM to S3"
        exit 1
    fi

    # Display success message
    echo ""
    print_success "SBOM uploaded successfully!"
    print_info "Location: $s3_path"
    echo ""
}

