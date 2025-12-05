#!/usr/bin/env bash

# Hello command implementation

cmd_hello() {
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
                echo "Run 'theodo-scan hello --help' for usage information."
                exit 1
                ;;
        esac
    done

    # Show help if requested
    if [ "$show_help" = true ]; then
        cat << EOF
Usage: theodo-scan hello [options]

Display a hello message and show your current configuration.

Options:
    -h, --help          Show this help message

Examples:
    theodo-scan hello

Note: Requires .theodorc file. Run 'theodo-scan init' first.

EOF
        exit 0
    fi

    # Check for configuration file
    if [ ! -f ".theodorc" ]; then
        print_error "Configuration file .theodorc not found in current directory."
        print_info "Please run 'theodo-scan init' first to create a configuration file."
        exit 1
    fi

    # Load configuration
    source ".theodorc"

    # Execute command
    print_header "🚀 Theodo Scan - Hello Command"
    echo ""

    print_success "Hello! Welcome to Theodo Scan."

    echo ""
    print_info "Configuration loaded from .theodorc:"
    print_info "  - Organization: $THEODO_SCAN_ORG"
    print_info "  - Project: $THEODO_SCAN_PROJECT"
    print_info "  - Component: $THEODO_SCAN_COMPONENT"

    echo ""
    print_info "This is a demonstration command."
    print_info "Run 'theodo-scan help' to see all available commands."
}

