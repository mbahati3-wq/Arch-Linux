#!/usr/bin/bash

# ============================================
# Cryptsetup Encryption Utilities
# Advanced LUKS encryption management and utilities
# ============================================

# Source color library
ENCRYPTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$ENCRYPTION_DIR")"
source "${PARENT_DIR}/lib/global-color.sh"

# ============================================
# Encryption Presets/Profiles
# ============================================

# Security level presets for different use cases
ENCRYPTION_PRESETS=(
    "standard"      # AES-256-XTS with SHA512 (balanced, recommended)
    "paranoid"      # AES-256-XTS with SHA512, extended iterations
    "performance"   # AES-128-XTS with SHA256 (faster, still secure)
    "legacy"        # LUKS1 with AES-256-CBC (old systems compatibility)
)

# Preset configurations
declare -A PRESET_CIPHER=(
    [standard]="aes-xts-plain64"
    [paranoid]="aes-xts-plain64"
    [performance]="aes-xts-plain64"
    [legacy]="aes-xts-plain64"
)

declare -A PRESET_KEY_SIZE=(
    [standard]="512"
    [paranoid]="512"
    [performance]="256"
    [legacy]="256"
)

declare -A PRESET_HASH=(
    [standard]="sha512"
    [paranoid]="sha512"
    [performance]="sha256"
    [legacy]="sha1"
)

declare -A PRESET_ITER_TIME=(
    [standard]="0"      # Default iteration time
    [paranoid]="4000"   # 4 seconds - very secure
    [performance]="1000" # 1 second - faster
    [legacy]="0"        # Default for LUKS1
)

declare -A PRESET_TYPE=(
    [standard]="luks2"
    [paranoid]="luks2"
    [performance]="luks2"
    [legacy]="luks1"
)

# ============================================
# Password Validation Functions
# ============================================

validate_password_strength() {
    local password="$1"
    local min_length="${2:-12}"
    local length=${#password}
    
    if [[ $length -lt $min_length ]]; then
        print_error "Password too short (minimum ${min_length} characters, got ${length})"
        return 1
    fi
    
    # Check for at least one uppercase
    if [[ ! "$password" =~ [A-Z] ]]; then
        print_warning "Password lacks uppercase letters (recommended for security)"
    fi
    
    # Check for at least one number
    if [[ ! "$password" =~ [0-9] ]]; then
        print_warning "Password lacks numbers (recommended for security)"
    fi
    
    # Check for at least one special character
    if ! echo "$password" | grep -qE '[!@#$%^&*()_+=\[\]{};:,.<>?/\\|-]'; then
        print_warning "Password lacks special characters (recommended for security)"
    fi
    
    print_success "Password strength: ✓ Acceptable"
    return 0
}

# ============================================
# LUKS Operations Functions
# ============================================

get_encryption_preset_config() {
    local preset="$1"
    
    # Validate preset
    if [[ ! " ${ENCRYPTION_PRESETS[@]} " =~ " ${preset} " ]]; then
        print_error "Unknown encryption preset: $preset"
        return 1
    fi
    
    echo "CIPHER=${PRESET_CIPHER[$preset]}"
    echo "KEY_SIZE=${PRESET_KEY_SIZE[$preset]}"
    echo "HASH=${PRESET_HASH[$preset]}"
    echo "ITER_TIME=${PRESET_ITER_TIME[$preset]}"
    echo "TYPE=${PRESET_TYPE[$preset]}"
    
    return 0
}

show_encryption_presets() {
    print_phase "Available Encryption Presets"
    
    echo ""
    print_info "Standard (Recommended):"
    echo "  Cipher: AES-256-XTS | Key: 512-bit | Hash: SHA512 | LUKS2"
    echo "  Use case: General-purpose systems (default)"
    echo ""
    
    print_info "Paranoid (Maximum Security):"
    echo "  Cipher: AES-256-XTS | Key: 512-bit | Hash: SHA512 | LUKS2"
    echo "  Iterations: 4000ms (much slower key derivation)"
    echo "  Use case: High-security servers, sensitive data"
    echo ""
    
    print_info "Performance (Balanced Speed):"
    echo "  Cipher: AES-128-XTS | Key: 256-bit | Hash: SHA256 | LUKS2"
    echo "  Use case: Systems where performance is critical"
    echo ""
    
    print_info "Legacy (Old Systems):"
    echo "  Cipher: AES-256-XTS | Key: 256-bit | Hash: SHA1 | LUKS1"
    echo "  Use case: Very old systems without LUKS2 support"
    echo ""
}

check_encryption_support() {
    print_status "Checking encryption tool availability..."
    
    if ! command -v cryptsetup &> /dev/null; then
        print_error "cryptsetup not found. Install it with: pacman -S cryptsetup"
        return 1
    fi
    
    print_success "cryptsetup is available"
    
    # Show version
    local version=$(cryptsetup --version | awk '{print $2}')
    print_info "cryptsetup version: $version"
    
    # Check for LUKS2 support
    if cryptsetup luksDump --unbound 2>&1 | grep -q "command not found"; then
        print_warning "LUKS2 support may be limited (old cryptsetup version)"
    else
        print_success "LUKS2 support: ✓ Available"
    fi
    
    return 0
}

# ============================================
# Interactive Encryption Setup
# ============================================

interactive_encryption_setup() {
    local device="$1"
    
    if [[ -z "$device" ]]; then
        print_error "Device not specified"
        return 1
    fi
    
    print_phase "Interactive LUKS Encryption Setup"
    
    # Show available presets
    show_encryption_presets
    
    # Ask for preset selection
    print_info "Select encryption preset:"
    echo "  1) standard (recommended)"
    echo "  2) paranoid (maximum security)"
    echo "  3) performance (faster)"
    echo "  4) legacy (LUKS1 for old systems)"
    echo ""
    read -p "Choose preset [1-4] (default: 1): " preset_choice
    preset_choice=${preset_choice:-1}
    
    case "$preset_choice" in
        1) ENCRYPTION_PRESET="standard" ;;
        2) ENCRYPTION_PRESET="paranoid" ;;
        3) ENCRYPTION_PRESET="performance" ;;
        4) ENCRYPTION_PRESET="legacy" ;;
        *) 
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    print_success "Selected preset: $ENCRYPTION_PRESET"
    
    # Load preset configuration
    eval "$(get_encryption_preset_config "$ENCRYPTION_PRESET")"
    
    # Ask for key file or password
    echo ""
    print_info "Encryption method:"
    echo "  1) Password (recommended for most users)"
    echo "  2) Key file (for automated unlocking)"
    echo ""
    read -p "Choose method [1-2] (default: 1): " method_choice
    method_choice=${method_choice:-1}
    
    case "$method_choice" in
        1)
            # Password-based encryption
            setup_luks_password "$device" "$TYPE" "$CIPHER" "$KEY_SIZE" "$HASH"
            ;;
        2)
            # Key file based encryption
            setup_luks_keyfile "$device" "$TYPE" "$CIPHER" "$KEY_SIZE" "$HASH"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    return 0
}

# ============================================
# Password-Based Encryption
# ============================================

setup_luks_password() {
    local device="$1"
    local luks_type="${2:-luks2}"
    local cipher="${3:-aes-xts-plain64}"
    local key_size="${4:-512}"
    local hash="${5:-sha512}"
    
    print_status "Setting up password-based LUKS encryption..."
    
    # Password entry loop
    while true; do
        echo ""
        print_info "🔐 Enter encryption password (will not be echoed):"
        read -s password1
        
        echo ""
        print_info "🔐 Confirm encryption password:"
        read -s password2
        
        if [[ "$password1" != "$password2" ]]; then
            print_warning "Passwords do not match, please try again"
            continue
        fi
        
        # Validate password strength
        if ! validate_password_strength "$password1" 12; then
            read -p "Continue anyway? (yes/no): " continue_weak
            if [[ ! "$continue_weak" =~ ^[Yy] ]]; then
                continue
            fi
        fi
        
        break
    done
    
    # Create encrypted partition
    print_status "Creating LUKS $luks_type encrypted partition..."
    echo -n "$password1" | cryptsetup -y -v --type "$luks_type" \
        --cipher "$cipher" \
        --key-size "$key_size" \
        --hash "$hash" \
        --use-random \
        luksFormat "$device" - || {
        print_error "LUKS encryption setup failed"
        return 1
    }
    
    # Clear password from memory (best effort)
    password1=""
    password2=""
    
    print_success "LUKS partition created successfully"
    
    return 0
}

setup_luks_keyfile() {
    local device="$1"
    local luks_type="${2:-luks2}"
    local cipher="${3:-aes-xts-plain64}"
    local key_size="${4:-512}"
    local hash="${5:-sha512}"
    
    print_status "Setting up key file-based LUKS encryption..."
    
    # Generate key file location
    local key_file="/root/luks-key-$(date +%s).key"
    
    echo ""
    print_warning "⚠️  Key file will be created at: $key_file"
    print_warning "⚠️  This file MUST be kept secure and backed up!"
    print_warning "⚠️  Without this file or password, data cannot be recovered!"
    echo ""
    
    read -p "Continue with key file setup? (yes/no): " confirm_keyfile
    if [[ ! "$confirm_keyfile" =~ ^[Yy] ]]; then
        print_error "Key file setup cancelled"
        return 1
    fi
    
    # Generate random key file
    print_status "Generating 4096-bit random key file..."
    dd if=/dev/urandom of="$key_file" bs=1024 count=4 2>&1 | grep -v records
    chmod 400 "$key_file"
    print_success "Key file created and permissions set to 400"
    
    # Create encrypted partition with key file
    print_status "Creating LUKS $luks_type encrypted partition..."
    cryptsetup -v --type "$luks_type" \
        --cipher "$cipher" \
        --key-size "$key_size" \
        --hash "$hash" \
        --use-random \
        luksFormat "$device" "$key_file" || {
        print_error "LUKS encryption setup failed"
        rm -f "$key_file"
        return 1
    }
    
    print_success "LUKS partition created with key file"
    print_warning "⚠️  Key file location: $key_file"
    
    return 0
}

# ============================================
# LUKS Management Functions
# ============================================

open_luks_partition() {
    local device="$1"
    local mapper_name="${2:-crypt_root}"
    
    if [[ -z "$device" ]]; then
        print_error "Device not specified"
        return 1
    fi
    
    print_status "Opening LUKS partition: $device → /dev/mapper/$mapper_name"
    
    cryptsetup open "$device" "$mapper_name" || {
        print_error "Failed to open LUKS partition"
        return 1
    }
    
    print_success "LUKS partition opened"
    
    return 0
}

close_luks_partition() {
    local mapper_name="${1:-crypt_root}"
    
    print_status "Closing LUKS partition: /dev/mapper/$mapper_name"
    
    cryptsetup close "$mapper_name" || {
        print_error "Failed to close LUKS partition"
        return 1
    }
    
    print_success "LUKS partition closed"
    
    return 0
}

get_luks_info() {
    local device="$1"
    
    if [[ -z "$device" ]]; then
        print_error "Device not specified"
        return 1
    fi
    
    if ! cryptsetup isLuks "$device" 2>/dev/null; then
        print_error "Device is not a LUKS partition: $device"
        return 1
    fi
    
    print_phase "LUKS Partition Information"
    print_info "Device: $device"
    echo ""
    
    cryptsetup luksDump "$device" | head -30
    
    return 0
}

change_luks_password() {
    local device="$1"
    local slot="${2:-0}"
    
    if [[ -z "$device" ]]; then
        print_error "Device not specified"
        return 1
    fi
    
    if ! cryptsetup isLuks "$device" 2>/dev/null; then
        print_error "Device is not a LUKS partition: $device"
        return 1
    fi
    
    print_status "Changing LUKS password on slot $slot..."
    cryptsetup luksChangeKey "$device" --key-slot "$slot" || {
        print_error "Failed to change password"
        return 1
    }
    
    print_success "Password changed successfully"
    
    return 0
}

backup_luks_header() {
    local device="$1"
    local backup_file="${2:-/root/luks-header-backup-$(date +%Y%m%d_%H%M%S).bin}"
    
    if [[ -z "$device" ]]; then
        print_error "Device not specified"
        return 1
    fi
    
    print_status "Backing up LUKS header from $device..."
    cryptsetup luksHeaderBackup "$device" --header-backup-file "$backup_file" || {
        print_error "Failed to backup LUKS header"
        return 1
    }
    
    print_success "LUKS header backed up to: $backup_file"
    print_warning "⚠️  Keep this backup in a safe place!"
    
    return 0
}

restore_luks_header() {
    local device="$1"
    local backup_file="$2"
    
    if [[ -z "$device" ]] || [[ -z "$backup_file" ]]; then
        print_error "Device and backup file must be specified"
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    print_warning "⚠️  This will overwrite the current LUKS header!"
    print_warning "⚠️  Current key slots will be lost!"
    read -p "Continue? (yes/no): " confirm_restore
    if [[ ! "$confirm_restore" =~ ^[Yy] ]]; then
        print_error "Header restore cancelled"
        return 1
    fi
    
    print_status "Restoring LUKS header from $backup_file..."
    cryptsetup luksHeaderRestore "$device" --header-backup-file "$backup_file" || {
        print_error "Failed to restore LUKS header"
        return 1
    }
    
    print_success "LUKS header restored successfully"
    
    return 0
}

# ============================================
# Benchmarking
# ============================================

benchmark_encryption_performance() {
    local device="${1:-/dev/null}"
    
    if [[ ! -e "$device" ]]; then
        print_error "Device not found: $device"
        return 1
    fi
    
    print_phase "Encryption Performance Benchmark"
    
    print_info "Benchmarking different cipher options..."
    print_warning "This may take a few minutes..."
    echo ""
    
    # Test ciphers
    local ciphers=("aes-xts-plain64" "aes-cbc-plain64" "twofish-xts-plain64")
    
    for cipher in "${ciphers[@]}"; do
        print_status "Testing cipher: $cipher"
        cryptsetup benchmark --cipher "$cipher" 2>&1 | grep -E "(iterations|bytes"
        echo ""
    done
    
    print_success "Benchmark complete"
    
    return 0
}

# ============================================
# Export Functions
# ============================================

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f validate_password_strength
    export -f get_encryption_preset_config
    export -f show_encryption_presets
    export -f check_encryption_support
    export -f interactive_encryption_setup
    export -f setup_luks_password
    export -f setup_luks_keyfile
    export -f open_luks_partition
    export -f close_luks_partition
    export -f get_luks_info
    export -f change_luks_password
    export -f backup_luks_header
    export -f restore_luks_header
    export -f benchmark_encryption_performance
fi
