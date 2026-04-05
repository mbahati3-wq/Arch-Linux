#!/usr/bin/bash

# ============================================
# Colorful Print Functions Library
# More informative than basic echo
# ============================================

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[0;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly UNDERLINE='\033[4m'
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'
readonly BG_YELLOW='\033[43m'
readonly BG_BLUE='\033[44m'
readonly NC='\033[0m' # No Color

# Icons for better visual feedback
readonly ICON_INFO="ℹ️"
readonly ICON_SUCCESS="✅"
readonly ICON_ERROR="❌"
readonly ICON_WARNING="⚠️"
readonly ICON_DEBUG="🐛"
readonly ICON_STEP="🚀"
readonly ICON_TIME="⏱️"

# Helper function to print colored text
print_color() {
    local message="$1"
    local color="$2"
    
    case "$color" in
        red)     echo -e "${RED}${message}${NC}" ;;
        green)   echo -e "${GREEN}${message}${NC}" ;;
        yellow)  echo -e "${YELLOW}${message}${NC}" ;;
        blue)    echo -e "${BLUE}${message}${NC}" ;;
        magenta) echo -e "${MAGENTA}${message}${NC}" ;;
        cyan)    echo -e "${CYAN}${message}${NC}" ;;
        white)   echo -e "${WHITE}${message}${NC}" ;;
        *)       echo -e "${message}" ;;
    esac
}

# Error handling function
print_error_msg() {
    local error_code="${2:-1}"  # Default error code 1 if not specified
    print_color "${ICON_ERROR} ERROR: $1" "red" >&2
    return "$error_code"
}

print_info() {
    print_color "${ICON_INFO} $1" "blue"
}

print_error() {
    print_color "${ICON_ERROR} ERROR: $1" "red" >&2
}

print_success() {
    print_color "${ICON_SUCCESS} $1" "green"
}

print_warning() {
    print_color "${ICON_WARNING} WARNING: $1" "yellow"
}

print_status() {
    print_color "${ICON_STEP} $1" "cyan"
}

print_debug() {
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        print_color "${ICON_DEBUG} DEBUG: $1" "magenta"
    fi
}

print_time() {
    print_color "${ICON_TIME} $1" "white"
}

# Enhanced error function with more details
print_detailed_error() {
    local message="$1"
    local error_code="${2:-1}"
    local line_no="${3:-${BASH_LINENO[1]}}"
    local function_name="${4:-${FUNCNAME[1]}}"
    
    echo -e "${BG_RED}${WHITE}${ICON_ERROR} ERROR DETAILS ${NC}" >&2
    print_color "${ICON_ERROR} Message: $message" "red" >&2
    print_color "${ICON_INFO} Location: $function_name() line $line_no" "yellow" >&2
    print_color "${ICON_INFO} Exit Code: $error_code" "yellow" >&2
    return "$error_code"
}

# Validation function with error messaging
validate_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        print_error "File not found: $file_path"
        return 1
    fi
    
    if [[ ! -r "$file_path" ]]; then
        print_error "File not readable: $file_path"
        return 2
    fi
    
    print_success "File validation passed: $file_path"
    return 0
}

# Validate directory exists
validate_directory() {
    local dir_path="$1"
    
    if [[ ! -d "$dir_path" ]]; then
        print_error "Directory not found: $dir_path"
        return 1
    fi
    
    if [[ ! -x "$dir_path" ]]; then
        print_error "Directory not accessible: $dir_path"
        return 2
    fi
    
    print_success "Directory validation passed: $dir_path"
    return 0
}

# Command execution with error handling
run_command() {
    local cmd="$1"
    local error_msg="${2:-Command failed}"
    
    print_status "Executing: $cmd"
    
    if eval "$cmd"; then
        print_success "Command completed successfully"
        return 0
    else
        local exit_code=$?
        print_error "$error_msg (exit code: $exit_code)"
        return "$exit_code"
    fi
}

# Try-catch like error handling
try_run() {
    local cmd="$1"
    local error_msg="${2:-Command failed}"
    
    if output=$(eval "$cmd" 2>&1); then
        echo "$output"
        return 0
    else
        local exit_code=$?
        print_detailed_error "$error_msg" "$exit_code"
        echo "$output" >&2
        return "$exit_code"
    fi
}

# Set error trap for debugging
set_error_trap() {
    set -E
    trap 'print_detailed_error "Unexpected error occurred" $? ${LINENO}' ERR
}

# Example usage and test function
test_error_handling() {
    echo "Testing error handling functions:"
    echo "================================"
    
    print_info "This is an info message"
    print_success "This is a success message"
    print_warning "This is a warning message"
    print_error "This is an error message"
    print_status "This is a status message"
    print_debug "This is a debug message (only shown if DEBUG_MODE=1)"
    print_time "Operation completed in 2.5 seconds"
    
    echo -e "\nTesting validation functions:"
    validate_file "/nonexistent/file.txt"
    validate_directory "/nonexistent/directory"
    
    echo -e "\nTesting command execution:"
    run_command "ls -la" "Failed to list directory"
    run_command "nonexistent_command" "Command not found"
}

# Export functions for use in other scripts
export -f print_color
export -f print_info
export -f print_error
export -f print_success
export -f print_warning
export -f print_status
export -f print_debug
export -f print_time
export -f print_error_msg
export -f print_detailed_error
export -f validate_file
export -f validate_directory
export -f run_command
export -f try_run
export -f set_error_trap

# Prevent direct execution of this script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is a library and should be sourced, not executed directly."
    echo "Usage: source $(basename "${BASH_SOURCE[0]}")"
    echo -e "\nOr to test the functions, run:"
    echo "source $(basename "${BASH_SOURCE[0]}") && test_error_handling"
    exit 1
fi