#!/usr/bin/bash

# ============================================
# Colorful Print Functions Library with Logging
# Prints to console AND writes to log files
# ============================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Source logger if available (optional)
if [[ -f "${SCRIPT_DIR}/logger.sh" ]]; then
    source "${SCRIPT_DIR}/logger.sh"
fi

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
readonly ICON_INPUT="📝"
readonly ICON_NETWORK="🌐"
readonly ICON_DISK="💾"
readonly ICON_PACKAGE="📦"

# Logging configuration
readonly LOG_DIR="${PARENT_DIR}/logs"
readonly SESSION_ID=$(date +"%Y%m%d_%H%M%S")
readonly LOG_FILE="${LOG_DIR}/console_${SESSION_ID}.log"
readonly ERROR_LOG_FILE="${LOG_DIR}/error_${SESSION_ID}.log"

# Log level (can be overridden)
LOG_LEVEL=${LOG_LEVEL:-6}  # 0=Emergency, 1=Alert, 2=Critical, 3=Error, 4=Warning, 5=Notice, 6=Info, 7=Debug

# Create log directory and files
setup_logging() {
    # Create log directory if it doesn't exist
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            echo "Warning: Could not create log directory: $LOG_DIR"
            return 1
        }
    fi
    
    # Initialize log files with headers
    for log_file in "$LOG_FILE" "$ERROR_LOG_FILE"; do
        touch "$log_file" 2>/dev/null || true
    done
    
    # Write session header
    write_log_header
}

write_log_header() {
    local header=$(cat <<EOF
===========================================
Arch Linux Automation Console Log
Session ID: $SESSION_ID
Start Time: $(date)
Host: $(hostname)
User: $(whoami)
Log Level: $LOG_LEVEL
===========================================

EOF
)
    echo "$header" >> "$LOG_FILE"
    echo "$header" >> "$ERROR_LOG_FILE"
}

# Core function to write to both console and log
write_output() {
    local message="$1"
    local log_level="$2"  # ERROR, WARNING, INFO, DEBUG, etc.
    local console_output="$3"  # Formatted with colors/icons for console
    local raw_message="$4"     # Plain message for log file
    
    # Write to console (with colors/icons)
    if [[ -n "$console_output" ]]; then
        echo -e "$console_output"
    else
        echo -e "$message"
    fi
    
    # Write to log file (plain text without colors)
    if [[ -n "$raw_message" ]]; then
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        echo "[$timestamp] [$log_level] $raw_message" >> "$LOG_FILE"
        
        # Also write to error log if it's an error
        if [[ "$log_level" == "ERROR" ]] || [[ "$log_level" == "CRITICAL" ]] || [[ "$log_level" == "EMERGENCY" ]]; then
            echo "[$timestamp] [$log_level] $raw_message" >> "$ERROR_LOG_FILE"
        fi
    fi
}

# Helper function to print colored text with logging
print_color() {
    local message="$1"
    local color="$2"
    local log_level="${3:-INFO}"
    local component="${4:-GENERAL}"
    
    local colored_message=""
    local plain_message="[$component] $message"
    
    case "$color" in
        red)     colored_message="${RED}${message}${NC}" ;;
        green)   colored_message="${GREEN}${message}${NC}" ;;
        yellow)  colored_message="${YELLOW}${message}${NC}" ;;
        blue)    colored_message="${BLUE}${message}${NC}" ;;
        magenta) colored_message="${MAGENTA}${message}${NC}" ;;
        cyan)    colored_message="${CYAN}${message}${NC}" ;;
        white)   colored_message="${WHITE}${message}${NC}" ;;
        bold)    colored_message="${BOLD}${message}${NC}" ;;
        *)       colored_message="${message}" ;;
    esac
    
    write_output "$message" "$log_level" "$colored_message" "$plain_message"
}

# Main print functions with dual output
print_info() {
    local message="$1"
    local component="${2:-INFO}"
    print_color "${ICON_INFO} $message" "blue" "INFO" "$component"
}

print_error() {
    local message="$1"
    local component="${2:-ERROR}"
    print_color "${ICON_ERROR} ERROR: $message" "red" "ERROR" "$component"
}

print_success() {
    local message="$1"
    local component="${2:-SUCCESS}"
    print_color "${ICON_SUCCESS} $message" "green" "INFO" "$component"
}

print_warning() {
    local message="$1"
    local component="${2:-WARNING}"
    print_color "${ICON_WARNING} WARNING: $message" "yellow" "WARNING" "$component"
}

print_status() {
    local message="$1"
    local component="${2:-STATUS}"
    print_color "${ICON_STEP} $message" "cyan" "INFO" "$component"
}

print_debug() {
    local message="$1"
    local component="${2:-DEBUG}"
    if [[ "${DEBUG_MODE:-0}" == "1" ]] || [[ $LOG_LEVEL -ge 7 ]]; then
        print_color "${ICON_DEBUG} DEBUG: $message" "magenta" "DEBUG" "$component"
    fi
}

print_time() {
    local message="$1"
    local component="${2:-TIME}"
    print_color "${ICON_TIME} $message" "white" "INFO" "$component"
}

print_input() {
    local message="$1"
    local component="${2:-INPUT}"
    print_color "${ICON_INPUT} $message" "bold" "INFO" "$component"
}

print_network() {
    local message="$1"
    local component="${2:-NETWORK}"
    print_color "${ICON_NETWORK} $message" "blue" "INFO" "$component"
}

print_disk() {
    local message="$1"
    local component="${2:-DISK}"
    print_color "${ICON_DISK} $message" "white" "INFO" "$component"
}

print_package() {
    local message="$1"
    local component="${2:-PACKAGE}"
    print_color "${ICON_PACKAGE} $message" "green" "INFO" "$component"
}

print_phase() {
    local message="$1"
    local component="${2:-PHASE}"
    local separator=$(printf '=%.0s' {1..50})
    print_color "\n${BOLD}${CYAN}${separator}${NC}" "cyan" "INFO" "$component"
    print_color "${BOLD}${CYAN}▶ $message${NC}" "cyan" "INFO" "$component"
    print_color "${BOLD}${CYAN}${separator}${NC}\n" "cyan" "INFO" "$component"
}

# Command execution with dual output (console + log)
run_and_log() {
    local cmd="$1"
    local description="$2"
    local component="${3:-EXEC}"
    local start_time=$(date +%s)
    
    print_status "Executing: $description" "$component"
    
    # Create a temporary file for command output
    local temp_output=$(mktemp)
    
    # Execute command, capturing both stdout and stderr
    if eval "$cmd" > >(tee -a "$temp_output") 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Log the output
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                write_output "$line" "INFO" "" "[$component] $line"
            fi
        done < "$temp_output"
        
        print_success "Command completed successfully (${duration}s)" "$component"
        rm -f "$temp_output"
        return 0
    else
        local exit_code=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Log the error output
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                write_output "$line" "ERROR" "" "[$component] $line"
            fi
        done < "$temp_output"
        
        print_error "Command failed: $description (exit code: $exit_code, duration: ${duration}s)" "$component"
        rm -f "$temp_output"
        return $exit_code
    fi
}

# Function to capture all output (stdout and stderr) to log
start_output_capture() {
    local capture_file="${LOG_DIR}/capture_${SESSION_ID}.log"
    exec 1> >(tee -a "$capture_file")
    exec 2> >(tee -a "$capture_file" >&2)
    print_info "Output capture started: $capture_file" "CAPTURE"
}

# Function to stop output capture
stop_output_capture() {
    exec 1>&2 2>&-
    print_info "Output capture stopped" "CAPTURE"
}

# Function to log system command output
log_command_output() {
    local cmd="$1"
    local description="$2"
    local component="${3:-SYSTEM}"
    
    print_info "Running: $description" "$component"
    
    local output=$(eval "$cmd" 2>&1)
    local exit_code=$?
    
    if [[ -n "$output" ]]; then
        # Split output into lines and log each
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                write_output "$line" "INFO" "" "[$component] $line"
            fi
        done <<< "$output"
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "$description completed" "$component"
    else
        print_error "$description failed with exit code $exit_code" "$component"
    fi
    
    return $exit_code
}

# Function to log file content
log_file_content() {
    local file_path="$1"
    local description="$2"
    local component="${3:-FILE}"
    
    if [[ -f "$file_path" ]]; then
        print_info "Content of $description: $file_path" "$component"
        while IFS= read -r line; do
            write_output "$line" "DEBUG" "" "[$component] $line"
        done < "$file_path"
    else
        print_error "File not found: $file_path" "$component"
        return 1
    fi
}

# Function to log variable values
log_variable() {
    local var_name="$1"
    local var_value="${!var_name}"
    local component="${2:-VARIABLE}"
    
    write_output "$var_name = $var_value" "DEBUG" "" "[$component] $var_name = $var_value"
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        print_debug "$var_name = $var_value" "$component"
    fi
}

# Function to create a checkpoint in logs
log_checkpoint() {
    local checkpoint_name="$1"
    local component="${2:-CHECKPOINT}"
    local separator=$(printf '=%.0s' {1..80})
    
    write_output "$separator" "INFO" "" "[$component] $separator"
    write_output "CHECKPOINT: $checkpoint_name" "INFO" "" "[$component] CHECKPOINT: $checkpoint_name"
    write_output "Time: $(date)" "INFO" "" "[$component] Time: $(date)"
    write_output "$separator" "INFO" "" "[$component] $separator"
    
    print_success "Checkpoint: $checkpoint_name" "$component"
}

# Function to get log file paths
get_log_paths() {
    cat <<EOF
===========================================
Log Files for Session: $SESSION_ID
===========================================
Console Log: $LOG_FILE
Error Log:   $ERROR_LOG_FILE
Log Directory: $LOG_DIR
===========================================
EOF
}

# Function to analyze logs
analyze_logs() {
    local log_file="${1:-$LOG_FILE}"
    
    if [[ ! -f "$log_file" ]]; then
        print_error "Log file not found: $log_file"
        return 1
    fi
    
    print_info "Analyzing log file: $log_file" "ANALYZER"
    
    local total_lines=$(wc -l < "$log_file")
    local error_count=$(grep -c "\[ERROR\]" "$log_file" 2>/dev/null || echo "0")
    local warning_count=$(grep -c "\[WARNING\]" "$log_file" 2>/dev/null || echo "0")
    local info_count=$(grep -c "\[INFO\]" "$log_file" 2>/dev/null || echo "0")
    local debug_count=$(grep -c "\[DEBUG\]" "$log_file" 2>/dev/null || echo "0")
    
    cat <<EOF
===========================================
Log Analysis Results
===========================================
Session ID: $SESSION_ID
Total Lines: $total_lines
Errors: $error_count
Warnings: $warning_count
Info Messages: $info_count
Debug Messages: $debug_count
===========================================
EOF
    
    if [[ $error_count -gt 0 ]]; then
        print_warning "Found $error_count errors. Check error log: $ERROR_LOG_FILE"
        echo ""
        echo "Last 5 errors:"
        grep "\[ERROR\]" "$log_file" | tail -5
    fi
}

# Initialize logging when script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    setup_logging
    print_info "Color logging library loaded" "LIBRARY"
    print_debug "Log file: $LOG_FILE" "LIBRARY"
fi

# Export functions for use in other scripts
export -f print_color
export -f print_info
export -f print_error
export -f print_success
export -f print_warning
export -f print_status
export -f print_debug
export -f print_time
export -f print_input
export -f print_network
export -f print_disk
export -f print_package
export -f print_phase
export -f run_and_log
export -f log_command_output
export -f log_file_content
export -f log_variable
export -f log_checkpoint
export -f get_log_paths
export -f analyze_logs
export -f start_output_capture
export -f stop_output_capture

# Export variables
export LOG_DIR
export SESSION_ID
export LOG_FILE
export ERROR_LOG_FILE
export LOG_LEVEL

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is a library and should be sourced, not executed directly."
    echo "Usage: source ${BASH_SOURCE[0]}"
    echo ""
    echo "Example usage:"
    echo "  source lib/color.sh"
    echo "  print_info 'Hello World'"
    echo "  run_and_log 'ls -la' 'List directory'"
    echo "  get_log_paths"
    echo "  analyze_logs"
    exit 1
fi