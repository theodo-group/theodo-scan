#!/usr/bin/env bash

# Hello command implementation

cmd_hello() {
    local name=""
    local show_help=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                name="$2"
                shift 2
                ;;
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

Display a hello message.

Options:
    -n, --name <name>   Specify a name to greet (optional)
    -h, --help          Show this help message

Examples:
    theodo-scan hello
    theodo-scan hello --name Alice
    theodo-scan hello -n Bob

EOF
        exit 0
    fi

    # Execute command
    print_header "🚀 Theodo Scan - Hello Command"
    echo ""

    if [ -n "$name" ]; then
        print_success "Hello, $name! Welcome to Theodo Scan."
    else
        print_success "Hello! Welcome to Theodo Scan."
    fi

    echo ""
    print_info "This is a demonstration command."
    print_info "Run 'theodo-scan help' to see all available commands."
}

