#!/usr/bin/env bash

# Run command implementation - combines scan and upload

cmd_run() {
    local show_help=false
    local bucket=""
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
            -p|--profile)
                aws_profile="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run 'theodo-scan run --help' for usage information."
                exit 1
                ;;
        esac
    done

    # Show help if requested
    if [ "$show_help" = true ]; then
        cat << EOF
Usage: theodo-scan run [options]

Run a security scan and upload the resulting SBOM to S3.

This command is a convenience shortcut that runs 'scan' followed by 'upload'.

Options:
    -b, --bucket <name>     S3 bucket name (overrides .theodorc)
    -p, --profile <name>    AWS CLI profile to use (overrides .theodorc)
    -h, --help              Show this help message

Examples:
    theodo-scan run
    theodo-scan run --bucket my-bucket --profile my-aws-profile

Note: Requires .theodorc file. Run 'theodo-scan init' first.
Required dependencies: trivy, jq, aws (AWS CLI)

EOF
        exit 0
    fi

    # Run scan
    source "$CLI_ROOT/lib/commands/scan.sh"
    cmd_scan

    # Build upload arguments
    local upload_args=()
    if [ -n "$bucket" ]; then
        upload_args+=("--bucket" "$bucket")
    fi
    if [ -n "$aws_profile" ]; then
        upload_args+=("--profile" "$aws_profile")
    fi

    # Run upload
    source "$CLI_ROOT/lib/commands/upload.sh"
    cmd_upload "${upload_args[@]}"
}
