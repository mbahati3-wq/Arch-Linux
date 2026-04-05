#!/usr/bin/bash

# ============================================
# Arch Linux Automation Logger
# Handles logging for installation scripts
# ============================================

# Source color functions if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/color.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/color.sh"
fi

# Logger configuration
readonly LOG_DIR="/var/log/arch-automation"
readonly SESSION_ID=$(date +"%Y%m%d_%H%M%S")
readonly LOG_FILE="${LOG_DIR}/arch_install_${SESSION_ID}.log"
readonly ERROR_LOG="${LOG_DIR}/arch_install_${SESSION_ID}_errors.log"
readonly DEBUG_LOG="${LOG_DIR}/arch_install_${SESSION_ID}_debug.log"

# Log levels
readonly LOG_LEVELS=(
    [0]="EMERGENCY"   # System is unusable
    [1]="ALERT"       # Action must be taken immediately
    [2]="CRITICAL"    # Critical conditions
    [3]="ERROR"       # Error conditions
    [4]="WARNING"     # Warning conditions
    [5]="NOTICE"      # Normal but significant condition
    [6]="INFO"        # Informational messages
    [7]="DEBUG"       # Debug-level messages
    [8]="TRACE"       # Function entry/exit
)

# Default log level (can be overridden)
LOG_LEVEL=${LOG_LEVEL:-6}  # Default to INFO

# Create log directory if it doesn't exist
setup_log_directories() {
    if [[ ! -d "$LOG_DIR" ]]; then
        sudo mkdir -p "$LOG_DIR" 2>/dev/null || mkdir -p "$LOG_DIR"
        sudo chmod 755 "$LOG_DIR" 2>/dev/null || chmod 755 "$LOG_DIR"
    fi
    
    # Initialize log files
    for log_file in "$LOG_FILE" "$ERROR_LOG" "$DEBUG_LOG"; do
        touch "$log_file"
        chmod 644 "$log_file" 2>/dev/null || true
    done
    
    # Write session header
    write_log_header
}

# Write session header to all logs
write_log_header() {
    local header=$(cat <<EOF
===========================================
Arch Linux Automation Installation Log
Session ID: $SESSION_ID
Start Time: $(date)
Host: $(hostname)
User: $(whoami)
Script: ${0}
===========================================

EOF
)
    
    echo "$header" >> "$LOG_FILE"
    echo "$header" >> "$ERROR_LOG"
    echo "$header" >> "$DEBUG_LOG"
}

# Core logging function
log_message() {
    local level=$1
    local message=$2
    local component=$3
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local level_name="${LOG_LEVELS[$level]}"
    
    # Only log if level <= current log level
    if [[ $level -le $LOG_LEVEL ]]; then
        local log_entry="[$timestamp] [$level_name] ${component:+[$component]} $message"
        
        # Always write to main log
        echo "$log_entry" >> "$LOG_FILE"
        
        # Write to error log for errors and above
        if [[ $level -le 3 ]]; then
            echo "$log_entry" >> "$ERROR_LOG"
        fi
        
        # Write to debug log for debug and trace
        if [[ $level -ge 7 ]]; then
            echo "$log_entry" >> "$DEBUG_LOG"
        fi
        
        # Console output with colors (if available)
        if [[ $level -le 3 ]]; then
            # Errors to stderr
            if [[ -n "$ICON_ERROR" ]]; then
                print_error "[$level_name] $message" >&2
            else
                echo -e "\033[0;31m❌ [$level_name] $message\033[0m" >&2
            fi
        elif [[ $level -eq 4 ]]; then
            # Warnings
            if [[ -n "$ICON_WARNING" ]]; then
                print_warning "[$level_name] $message"
            else
                echo -e "\033[0;33m⚠️ [$level_name] $message\033[0m"
            fi
        elif [[ $level -eq 5 ]]; then
            # Notice
            if [[ -n "$ICON_INFO" ]]; then
                print_info "[$level_name] $message"
            else
                echo -e "\033[0;34mℹ️ [$level_name] $message\033[0m"
            fi
        elif [[ $level -eq 6 ]]; then
            # Info
            if [[ -n "$ICON_INFO" ]]; then
                print_info "$message"
            else
                echo -e "\033[0;36mℹ️ $message\033[0m"
            fi
        fi
    fi
}

# Convenience functions for different log levels
log_emergency() { log_message 0 "$1" "$2"; }
log_alert()     { log_message 1 "$1" "$2"; }
log_critical()  { log_message 2 "$1" "$2"; }
log_error()     { log_message 3 "$1" "$2"; }
log_warning()   { log_message 4 "$1" "$2"; }
log_notice()    { log_message 5 "$1" "$2"; }
log_info()      { log_message 6 "$1" "$2"; }
log_debug()     { log_message 7 "$1" "$2"; }
log_trace()     { log_message 8 "$1" "$2"; }

# Installation phase logging
log_phase_start() {
    local phase_name="$1"
    local separator=$(printf '=%.0s' {1..60})
    
    log_info "$separator" "PHASE"
    log_info "STARTING PHASE: $phase_name" "PHASE"
    log_info "Timestamp: $(date)" "PHASE"
    log_info "$separator" "PHASE"
    
    # Also output to console clearly
    if [[ -n "$ICON_STEP" ]]; then
        print_status "🚀 Starting phase: $phase_name"
    else
        echo -e "\n\033[1;36m>>> Starting phase: $phase_name <<<\033[0m\n"
    fi
}

log_phase_complete() {
    local phase_name="$1"
    local duration="$2"
    local separator=$(printf '=%.0s' {1..60})
    
    log_info "$separator" "PHASE"
    log_info "COMPLETED PHASE: $phase_name" "PHASE"
    log_info "Duration: ${duration}s" "PHASE"
    log_info "$separator" "PHASE"
    
    if [[ -n "$ICON_SUCCESS" ]]; then
        print_success "✅ Completed phase: $phase_name (${duration}s)"
    else
        echo -e "\033[0;32m✅ Completed phase: $phase_name (${duration}s)\033[0m"
    fi
}

# Command execution with logging
run_logged() {
    local cmd="$1"
    local description="$2"
    local component="${3:-EXEC}"
    local start_time=$(date +%s)
    
    log_info "Executing: $description" "$component"
    log_debug "Command: $cmd" "$component"
    
    # Execute command and capture output
    if eval "$cmd" 2>>"$ERROR_LOG"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_info "Success: $description (completed in ${duration}s)" "$component"
        return 0
    else
        local exit_code=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "Failed: $description (exit code: $exit_code, duration: ${duration}s)" "$component"
        log_error "Command that failed: $cmd" "$component"
        return $exit_code
    fi
}

# Package installation logging
log_package_install() {
    local package_name="$1"
    local package_manager="$2"  # pacman, yay, paru, etc.
    
    log_info "Installing package: $package_name" "PKG_$package_manager"
    log_debug "Package manager: $package_manager" "PKG_$package_name"
}

log_package_success() {
    local package_name="$1"
    local duration="$2"
    
    log_info "Successfully installed: $package_name (${duration}s)" "PKG"
}

log_package_failure() {
    local package_name="$1"
    local error_msg="$2"
    
    log_error "Failed to install: $package_name" "PKG"
    log_error "Error: $error_msg" "PKG"
}

# System state logging
log_system_state() {
    local state_type="$1"  # disk, network, services, etc.
    
    case "$state_type" in
        disk)
            log_info "Disk state:" "SYSTEM"
            df -h >> "$LOG_FILE"
            lsblk >> "$LOG_FILE"
            ;;
        network)
            log_info "Network state:" "SYSTEM"
            ip addr show >> "$LOG_FILE"
            ping -c 1 archlinux.org >> "$LOG_FILE" 2>/dev/null
            ;;
        services)
            log_info "Service state:" "SYSTEM"
            systemctl list-units --type=service --state=running >> "$LOG_FILE"
            ;;
        memory)
            log_info "Memory state:" "SYSTEM"
            free -h >> "$LOG_FILE"
            ;;
        processes)
            log_info "Process state:" "SYSTEM"
            ps aux --sort=-%mem | head -20 >> "$LOG_FILE"
            ;;
    esac
}

# Boot and UEFI logging
log_boot_setup() {
    log_info "Boot mode: $(ls /sys/firmware/efi/efivars 2>/dev/null && echo 'UEFI' || echo 'BIOS')" "BOOT"
    
    if [[ -d /sys/firmware/efi ]]; then
        log_info "UEFI detected - configuring UEFI boot" "BOOT"
        log_debug "EFI variables accessible: $(ls -la /sys/firmware/efi/efivars | wc -l)" "BOOT"
    else
        log_warning "BIOS mode detected - legacy boot configuration" "BOOT"
    fi
}

# Hardware detection logging
log_hardware() {
    log_info "Hardware detection:" "HARDWARE"
    
    # CPU info
    local cpu_model=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
    local cpu_cores=$(nproc)
    log_info "CPU: $cpu_model ($cpu_cores cores)" "HARDWARE"
    
    # RAM info
    local total_ram=$(free -h | awk '/^Mem:/ {print $2}')
    log_info "RAM: $total_ram" "HARDWARE"
    
    # Disk info
    log_info "Disks:" "HARDWARE"
    lsblk -d -o NAME,SIZE,MODEL | grep -v "loop" >> "$LOG_FILE"
    
    # GPU info
    if command -v lspci &>/dev/null; then
        local gpu=$(lspci | grep -E "VGA|3D" | cut -d':' -f3 | xargs)
        log_info "GPU: $gpu" "HARDWARE"
    fi
}

# Error summary generation
generate_error_summary() {
    local error_count=$(grep -c "\[ERROR\]" "$LOG_FILE" 2>/dev/null || echo "0")
    local warning_count=$(grep -c "\[WARNING\]" "$LOG_FILE" 2>/dev/null || echo "0")
    
    cat <<EOF

===========================================
INSTALLATION SUMMARY
===========================================
Session ID: $SESSION_ID
Total Errors: $error_count
Total Warnings: $warning_count
Log File: $LOG_FILE
Error Log: $ERROR_LOG

EOF
    
    if [[ $error_count -gt 0 ]]; then
        echo "Error details:"
        grep "\[ERROR\]" "$LOG_FILE" | tail -10
        echo ""
        echo "Check $ERROR_LOG for complete error list"
    fi
}

# Function to log time for each major step (for performance tracking)
log_timing() {
    local step_name="$1"
    local start_time="$2"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_info "TIMING: $step_name took ${duration} seconds" "PERF"
    
    # Log to separate timing file for analysis
    echo "$(date +"%Y-%m-%d %H:%M:%S"),$step_name,$duration" >> "${LOG_DIR}/timing_${SESSION_ID}.csv"
}

# Initialize logging system
init_logging() {
    setup_log_directories
    log_info "Logging system initialized" "LOGGER"
    log_info "Log file: $LOG_FILE" "LOGGER"
    log_info "Error log: $ERROR_LOG" "LOGGER"
    log_debug "Debug log: $DEBUG_LOG" "LOGGER"
    
    # Log initial system state
    log_hardware
    log_boot_setup
}

# Export functions
export -f log_emergency log_alert log_critical log_error log_warning
export -f log_notice log_info log_debug log_trace
export -f log_phase_start log_phase_complete
export -f run_logged log_package_install log_package_success log_package_failure
export -f log_system_state log_hardware generate_error_summary init_logging
export -f log_timing

# Auto-initialize if script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Being sourced, initialize logging
    init_logging
fi

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This is a library script and should be sourced"
    echo "Usage: source ${BASH_SOURCE[0]}"
    exit 1
fi