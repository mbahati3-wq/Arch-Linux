#!/usr/bin/bash

# ============================================
# Arch Linux Disk Partitioner with LVM + LUKS
# Supports UEFI/GPT, LVM, and Encryption
# ============================================

# Source color library for colorful output
source ../lib/global-color.sh

# ============================================
# Configuration Variables (Easily Changeable)
# ============================================

# Disk configuration
DISK="${DISK:-/dev/sda}"                    # Target disk
EFI_SIZE="${EFI_SIZE:-512}"                 # EFI partition size in MiB
SWAP_SIZE="${SWAP_SIZE:-8192}"              # Swap size in MiB (8GB default)
ENABLE_ENCRYPTION="${ENABLE_ENCRYPTION:-true}"  # Enable LUKS encryption

# LVM Volume Group and Logical Volume names (easily changeable)
VG_NAME="${VG_NAME:-vg0}"                   # Volume Group name
LV_ROOT_NAME="${LV_ROOT_NAME:-lv_root}"     # Root logical volume name
LV_HOME_NAME="${LV_HOME_NAME:-lv_home}"     # Home logical volume name
LV_SWAP_NAME="${LV_SWAP_NAME:-lv_swap}"     # Swap logical volume name
LV_VAR_NAME="${LV_VAR_NAME:-lv_var}"        # Var logical volume name

# Size allocations (in GiB)
ROOT_SIZE="${ROOT_SIZE:-30}"                # Root partition size (30GB)
HOME_SIZE="${HOME_SIZE:-100}"               # Home partition size (100GB)
VAR_SIZE="${VAR_SIZE:-20}"                  # Var partition size (20GB)
# Swap size is defined above in MiB

# Encryption options
LUKS_TYPE="${LUKS_TYPE:-luks2}"             # LUKS version (luks1 or luks2)
LUKS_CIPHER="${LUKS_CIPHER:-aes-xts-plain64}" # Cipher for encryption
LUKS_KEY_SIZE="${LUKS_KEY_SIZE:-512}"       # Key size in bits
LUKS_HASH="${LUKS_HASH:-sha512}"            # Hash algorithm

# Mount points
EFI_MOUNT="${EFI_MOUNT:-/boot}"             # EFI partition mount point (or /boot/efi)
LVM_MOUNT_OPTIONS="${LVM_MOUNT_OPTIONS:-defaults,noatime}"

# Log file for partitioning operations
LOG_FILE="${LOG_FILE:-/tmp/partitioning_$(date +%Y%m%d_%H%M%S).log}"

# ============================================
# Helper Functions
# ============================================

log_output() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_success "Found: $1"
        return 0
    else
        print_error "Missing: $1"
        return 1
    fi
}

validate_prerequisites() {
    print_status "Checking prerequisites..."
    
    local required_commands=("parted" "lsblk" "pvcreate" "vgcreate" "lvcreate" "cryptsetup")
    
    for cmd in "${required_commands[@]}"; do
        if ! check_command "$cmd"; then
            print_error "Please install $cmd before continuing"
            return 1
        fi
    done
    
    print_success "All prerequisites satisfied"
    return 0
}

# ============================================
# Validation Functions
# ============================================

validate_disk() {
    if [[ ! -b "$DISK" ]]; then
        print_error "Disk $DISK does not exist or is not a block device"
        return 1
    fi
    
    # Check if disk is already mounted
    if mount | grep -q "^$DISK"; then
        print_error "Disk $DISK is currently mounted"
        return 1
    fi
    
    print_success "Disk validation passed: $DISK"
    return 0
}

confirm_partitioning() {
    print_warning "⚠️  This will DESTROY ALL DATA on $DISK"
    print_info "📋 Partitioning Plan:"
    echo ""
    print_info "Disk: $DISK"
    echo ""
    print_info "📊 Partition Layout:"
    echo "  ├── ${DISK}1 - EFI System Partition (${EFI_SIZE}MiB, FAT32) → $EFI_MOUNT"
    echo "  └── ${DISK}2 - LVM Physical Volume (Remaining space)"
    echo "       └── 🔐 LUKS Encryption: $ENABLE_ENCRYPTION"
    echo "            └── Volume Group: $VG_NAME"
    echo "                 ├── $LV_ROOT_NAME (${ROOT_SIZE}GiB) → /"
    echo "                 ├── $LV_HOME_NAME (${HOME_SIZE}GiB) → /home"
    echo "                 ├── $LV_SWAP_NAME (${SWAP_SIZE}MiB) → swap"
    echo "                 └── $LV_VAR_NAME (${VAR_SIZE}GiB) → /var"
    echo ""
    
    read -p "Do you want to continue? (yes/NO): " confirmation
    if [[ ! "$confirmation" =~ ^[Yy](es)?$ ]]; then
        print_error "Partitioning cancelled by user"
        return 1
    fi
    
    return 0
}

# ============================================
# Partitioning Functions
# ============================================

wipe_disk() {
    print_status "Wiping existing partition table on $DISK..."
    
    # Zap all signatures
    wipefs -a "$DISK" 2>&1 | tee -a "$LOG_FILE"
    
    # Create new GPT partition table
    parted "$DISK" mklabel gpt --script 2>&1 | tee -a "$LOG_FILE"
    
    print_success "Disk wiped and GPT label created"
}

create_efi_partition() {
    print_status "Creating EFI System Partition..."
    
    # Create EFI partition (512MiB)
    parted "$DISK" mkpart primary fat32 1MiB ${EFI_SIZE}MiB --script 2>&1 | tee -a "$LOG_FILE"
    parted "$DISK" set 1 esp on --script 2>&1 | tee -a "$LOG_FILE"
    
    # Format as FAT32
    mkfs.fat -F32 "${DISK}1" 2>&1 | tee -a "$LOG_FILE"
    
    print_success "EFI partition created: ${DISK}1"
}

create_lvm_partition() {
    print_status "Creating LVM partition..."
    
    # Create LVM partition using remaining space
    parted "$DISK" mkpart primary ext4 ${EFI_SIZE}MiB 100% --script 2>&1 | tee -a "$LOG_FILE"
    parted "$DISK" set 2 lvm on --script 2>&1 | tee -a "$LOG_FILE"
    
    print_success "LVM partition created: ${DISK}2"
}

# ============================================
# Encryption Functions
# ============================================

setup_encryption() {
    if [[ "$ENABLE_ENCRYPTION" != "true" ]]; then
        print_warning "Encryption disabled, skipping LUKS setup"
        return 0
    fi
    
    print_status "Setting up LUKS encryption on ${DISK}2..."
    
    # Prompt for passphrase
    echo ""
    print_info "🔐 Enter encryption passphrase for LUKS:"
    cryptsetup -y -v --type "$LUKS_TYPE" \
        --cipher "$LUKS_CIPHER" \
        --key-size "$LUKS_KEY_SIZE" \
        --hash "$LUKS_HASH" \
        --use-random \
        luksFormat "${DISK}2" 2>&1 | tee -a "$LOG_FILE"
    
    if [[ $? -ne 0 ]]; then
        print_error "LUKS encryption setup failed"
        return 1
    fi
    
    # Open the encrypted partition
    print_status "Opening encrypted partition..."
    cryptsetup open "${DISK}2" "${VG_NAME}" 2>&1 | tee -a "$LOG_FILE"
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to open encrypted partition"
        return 1
    fi
    
    # Set the physical volume path to the mapped device
    PV_DEVICE="/dev/mapper/${VG_NAME}"
    print_success "Encryption setup complete. Mapped to: $PV_DEVICE"
    
    return 0
}

# ============================================
# LVM Functions
# ============================================

setup_lvm() {
    local pv_device
    
    if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
        pv_device="/dev/mapper/${VG_NAME}"
    else
        pv_device="${DISK}2"
    fi
    
    print_status "Setting up LVM on $pv_device..."
    
    # Create Physical Volume
    print_status "Creating Physical Volume (PV)..."
    pvcreate "$pv_device" 2>&1 | tee -a "$LOG_FILE"
    
    # Create Volume Group
    print_status "Creating Volume Group (VG): $VG_NAME..."
    vgcreate "$VG_NAME" "$pv_device" 2>&1 | tee -a "$LOG_FILE"
    
    # Create Logical Volumes
    print_status "Creating Logical Volumes (LVs)..."
    
    # Root LV
    lvcreate -L "${ROOT_SIZE}G" -n "$LV_ROOT_NAME" "$VG_NAME" 2>&1 | tee -a "$LOG_FILE"
    
    # Home LV
    lvcreate -L "${HOME_SIZE}G" -n "$LV_HOME_NAME" "$VG_NAME" 2>&1 | tee -a "$LOG_FILE"
    
    # Var LV
    lvcreate -L "${VAR_SIZE}G" -n "$LV_VAR_NAME" "$VG_NAME" 2>&1 | tee -a "$LOG_FILE"
    
    # Swap LV
    lvcreate -L "${SWAP_SIZE}M" -n "$LV_SWAP_NAME" "$VG_NAME" 2>&1 | tee -a "$LOG_FILE"
    
    print_success "LVM setup complete"
}

format_logical_volumes() {
    print_status "Formatting logical volumes..."
    
    # Format root (ext4)
    mkfs.ext4 "/dev/${VG_NAME}/${LV_ROOT_NAME}" 2>&1 | tee -a "$LOG_FILE"
    
    # Format home (ext4)
    mkfs.ext4 "/dev/${VG_NAME}/${LV_HOME_NAME}" 2>&1 | tee -a "$LOG_FILE"
    
    # Format var (ext4)
    mkfs.ext4 "/dev/${VG_NAME}/${LV_VAR_NAME}" 2>&1 | tee -a "$LOG_FILE"
    
    # Format swap
    mkswap "/dev/${VG_NAME}/${LV_SWAP_NAME}" 2>&1 | tee -a "$LOG_FILE"
    
    print_success "All logical volumes formatted"
}

# ============================================
# Mounting Functions
# ============================================

mount_partitions() {
    print_status "Mounting partitions..."
    
    # Mount root
    mount "/dev/${VG_NAME}/${LV_ROOT_NAME}" /mnt
    
    # Create directories
    mkdir -p /mnt/{boot,home,var}
    
    # Mount EFI partition
    mount "${DISK}1" "/mnt${EFI_MOUNT}"
    
    # Mount home
    mount "/dev/${VG_NAME}/${LV_HOME_NAME}" /mnt/home
    
    # Mount var
    mount "/dev/${VG_NAME}/${LV_VAR_NAME}" /mnt/var
    
    # Enable swap
    swapon "/dev/${VG_NAME}/${LV_SWAP_NAME}"
    
    print_success "All partitions mounted"
}

# ============================================
# Crypttab and Fstab Generation
# ============================================

generate_crypttab() {
    if [[ "$ENABLE_ENCRYPTION" != "true" ]]; then
        return 0
    fi
    
    print_status "Generating crypttab..."
    
    # Get UUID of the encrypted partition
    local uuid=$(blkid -s UUID -o value "${DISK}2")
    
    # Create crypttab entry
    cat > /mnt/etc/crypttab << EOF
# <target name> <source device> <key file> <options>
${VG_NAME} UUID=${uuid} none luks
EOF
    
    print_success "Crypttab generated"
}

generate_fstab() {
    print_status "Generating fstab..."
    
    # Generate fstab
    genfstab -U /mnt >> /mnt/etc/fstab 2>&1
    
    # Verify fstab was created
    if [[ -f /mnt/etc/fstab ]]; then
        print_success "Fstab generated successfully"
        print_info "Fstab content preview:"
        head -10 /mnt/etc/fstab | tee -a "$LOG_FILE"
    else
        print_error "Failed to generate fstab"
        return 1
    fi
}

# ============================================
# Summary Function
# ============================================

show_summary() {
    echo ""
    print_success "=========================================="
    print_success "✅ PARTITIONING COMPLETED SUCCESSFULLY"
    print_success "=========================================="
    echo ""
    print_info "📊 Partition Layout Summary:"
    echo ""
    
    lsblk "$DISK" | tee -a "$LOG_FILE"
    
    echo ""
    print_info "💾 LVM Status:"
    lvs | tee -a "$LOG_FILE"
    
    echo ""
    print_info "🔐 Encryption Status:"
    if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
        cryptsetup status "${VG_NAME}" 2>&1 | tee -a "$LOG_FILE"
    else
        echo "Encryption: Disabled"
    fi
    
    echo ""
    print_info "📁 Mount Points:"
    mount | grep "/mnt" | tee -a "$LOG_FILE"
    
    echo ""
    print_info "📝 Log file saved to: $LOG_FILE"
    echo ""
    print_warning "IMPORTANT: Remember to:"
    echo "  1. Install base system: pacstrap /mnt base linux linux-firmware lvm2 vim"
    echo "  2. Generate fstab: genfstab -U /mnt >> /mnt/etc/fstab"
    echo "  3. Chroot: arch-chroot /mnt"
    echo "  4. Configure mkinitcpio to include encrypt and lvm2 hooks"
    echo "  5. Update GRUB for encryption support"
}

# ============================================
# Main Function
# ============================================

main() {
    clear
    print_info "🚀 Arch Linux Disk Partitioner with LVM + LUKS"
    print_info "============================================="
    echo ""
    
    # Validate prerequisites
    if ! validate_prerequisites; then
        print_error "Missing required tools. Please install and try again."
        exit 1
    fi
    
    # Validate disk
    if ! validate_disk; then
        exit 1
    fi
    
    # Show configuration and get confirmation
    if ! confirm_partitioning; then
        exit 1
    fi
    
    # Execute partitioning steps
    wipe_disk
    create_efi_partition
    create_lvm_partition
    
    # Setup encryption if enabled
    if ! setup_encryption; then
        print_error "Encryption setup failed"
        exit 1
    fi
    
    # Setup LVM
    if ! setup_lvm; then
        print_error "LVM setup failed"
        exit 1
    fi
    
    # Format volumes
    format_logical_volumes
    
    # Mount partitions
    mount_partitions
    
    # Generate crypttab and fstab
    if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
        generate_crypttab
    fi
    generate_fstab
    
    # Show summary
    show_summary
    
    print_success "Partitioning complete! You can now continue with Arch Linux installation."
}

# ============================================
# Script Execution
# ============================================

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (sudo)"
        exit 1
    fi
    
    main "$@"
fi