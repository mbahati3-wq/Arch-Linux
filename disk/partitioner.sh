#!/usr/bin/bash

# ============================================
# Arch Linux Disk Partitioner with LVM + LUKS
# Supports UEFI/GPT, BIOS/MBR, LVM, and Encryption
# ============================================

# Source color library for colorful output
DISK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$DISK_DIR")"
source "${PARENT_DIR}/lib/global-color.sh"

# ============================================
# Configuration Variables (Easily Changeable)
# ============================================

# Boot mode and disk configuration
BOOT_MODE="${BOOT_MODE:-auto}"              # auto, uefi, or bios
DISK="${DISK:-/dev/sda}"                    # Target disk
EFI_SIZE="${EFI_SIZE:-512}"                 # EFI partition size in MiB (UEFI only)
BIOS_BOOT_SIZE="${BIOS_BOOT_SIZE:-2}"       # BIOS boot partition size in MiB (BIOS only)
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
ENCRYPTION_PRESET="${ENCRYPTION_PRESET:-standard}"  # standard, paranoid, performance, legacy
LUKS_TYPE="${LUKS_TYPE:-luks2}"             # LUKS version (luks1 or luks2)
LUKS_CIPHER="${LUKS_CIPHER:-aes-xts-plain64}" # Cipher for encryption
LUKS_KEY_SIZE="${LUKS_KEY_SIZE:-512}"       # Key size in bits
LUKS_HASH="${LUKS_HASH:-sha512}"            # Hash algorithm
ENCRYPTION_ITER_TIME="${ENCRYPTION_ITER_TIME:-0}"  # Iteration time (ms), 0 = default

# Mount points
EFI_MOUNT="${EFI_MOUNT:-/boot}"             # EFI partition mount point (or /boot/efi)
LVM_MOUNT_OPTIONS="${LVM_MOUNT_OPTIONS:-defaults,noatime}"

# Log file for partitioning operations
LOG_FILE="${LOG_FILE:-/tmp/partitioning_$(date +%Y%m%d_%H%M%S).log}"

# ============================================
# Boot Mode Detection Function
# ============================================

detect_boot_mode() {
    if [[ "$BOOT_MODE" == "auto" ]]; then
        if [[ -d "/sys/firmware/efi" ]]; then
            BOOT_MODE="uefi"
            print_success "Detected UEFI boot mode"
        else
            BOOT_MODE="bios"
            print_info "Detected BIOS/Legacy boot mode"
        fi
    else
        print_info "Using configured boot mode: $BOOT_MODE"
    fi
}

load_encryption_preset() {
    local preset="$1"
    
    case "$preset" in
        standard)
            LUKS_TYPE="luks2"
            LUKS_CIPHER="aes-xts-plain64"
            LUKS_KEY_SIZE="512"
            LUKS_HASH="sha512"
            ENCRYPTION_ITER_TIME="0"
            print_success "Loaded encryption preset: standard (recommended)"
            ;;
        paranoid)
            LUKS_TYPE="luks2"
            LUKS_CIPHER="aes-xts-plain64"
            LUKS_KEY_SIZE="512"
            LUKS_HASH="sha512"
            ENCRYPTION_ITER_TIME="4000"
            print_success "Loaded encryption preset: paranoid (maximum security)"
            ;;
        performance)
            LUKS_TYPE="luks2"
            LUKS_CIPHER="aes-xts-plain64"
            LUKS_KEY_SIZE="256"
            LUKS_HASH="sha256"
            ENCRYPTION_ITER_TIME="1000"
            print_success "Loaded encryption preset: performance"
            ;;
        legacy)
            LUKS_TYPE="luks1"
            LUKS_CIPHER="aes-xts-plain64"
            LUKS_KEY_SIZE="256"
            LUKS_HASH="sha1"
            ENCRYPTION_ITER_TIME="0"
            print_success "Loaded encryption preset: legacy (LUKS1)"
            ;;
        *)
            print_warning "Unknown encryption preset: $preset, using standard"
            ENCRYPTION_PRESET="standard"
            load_encryption_preset "standard"
            ;;
    esac
}

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
    print_info "Boot Mode: $BOOT_MODE"
    echo ""
    print_info "📊 Partition Layout:"
    
    if [[ "$BOOT_MODE" == "uefi" ]]; then
        echo "  ├── ${DISK}1 - EFI System Partition (${EFI_SIZE}MiB, FAT32) → $EFI_MOUNT"
        echo "  └── ${DISK}2 - LVM Physical Volume (Remaining space)"
    else
        echo "  ├── ${DISK}1 - BIOS Boot Partition (${BIOS_BOOT_SIZE}MiB, unformatted) → reserved"
        echo "  ├── ${DISK}2 - Boot Partition (512MiB, ext4) → /boot"
        echo "  └── ${DISK}3 - LVM Physical Volume (Remaining space)"
    fi
    
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
    
    # Create partition table based on boot mode
    if [[ "$BOOT_MODE" == "uefi" ]]; then
        print_status "Creating GPT partition table for UEFI..."
        parted "$DISK" mklabel gpt --script 2>&1 | tee -a "$LOG_FILE"
        print_success "Disk wiped and GPT label created"
    else
        print_status "Creating MBR partition table for BIOS..."
        parted "$DISK" mklabel msdos --script 2>&1 | tee -a "$LOG_FILE"
        print_success "Disk wiped and MBR label created"
    fi
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

create_bios_partitions() {
    print_phase "Creating BIOS Boot Partition Layout"
    
    # Create BIOS boot partition (required by GRUB on MBR)
    print_status "Creating BIOS boot partition (${BIOS_BOOT_SIZE}MiB)..."
    parted "$DISK" mkpart primary 1MiB ${BIOS_BOOT_SIZE}MiB --script 2>&1 | tee -a "$LOG_FILE"
    parted "$DISK" set 1 bios_grub on --script 2>&1 | tee -a "$LOG_FILE"
    print_success "BIOS boot partition created: ${DISK}1"
    
    # Create /boot partition (ext4)
    print_status "Creating /boot partition (512MiB)..."
    local boot_start=$((BIOS_BOOT_SIZE + 1))
    local boot_end=$((BIOS_BOOT_SIZE + 512))
    parted "$DISK" mkpart primary ext4 ${boot_start}MiB ${boot_end}MiB --script 2>&1 | tee -a "$LOG_FILE"
    mkfs.ext4 "${DISK}2" 2>&1 | tee -a "$LOG_FILE"
    print_success "/boot partition created: ${DISK}2"
    
    # LVM partition will be created next (partition 3)
}

create_lvm_partition() {
    print_status "Creating LVM partition..."
    
    # Determine which partition number to use based on boot mode
    local lvm_partition
    local lvm_start
    
    if [[ "$BOOT_MODE" == "uefi" ]]; then
        lvm_partition="${DISK}2"
        lvm_start=${EFI_SIZE}MiB
    else
        lvm_partition="${DISK}3"
        lvm_start=$((BIOS_BOOT_SIZE + 512 + 1))MiB
    fi
    
    # Create LVM partition using remaining space
    parted "$DISK" mkpart primary ext4 ${lvm_start} 100% --script 2>&1 | tee -a "$LOG_FILE"
    parted "$DISK" set $(echo "$lvm_partition" | grep -o '[0-9]*$') lvm on --script 2>&1 | tee -a "$LOG_FILE"
    
    print_success "LVM partition created: $lvm_partition"
}

# ============================================
# Encryption Functions
# ============================================

setup_encryption() {
    if [[ "$ENABLE_ENCRYPTION" != "true" ]]; then
        print_warning "Encryption disabled, skipping LUKS setup"
        return 0
    fi
    
    # Determine LVM partition based on boot mode
    local lvm_partition
    if [[ "$BOOT_MODE" == "uefi" ]]; then
        lvm_partition="${DISK}2"
    else
        lvm_partition="${DISK}3"
    fi
    
    print_status "Setting up LUKS encryption on $lvm_partition..."
    print_info "Encryption details:"
    echo "  Type: $LUKS_TYPE"
    echo "  Cipher: $LUKS_CIPHER"
    echo "  Key Size: ${LUKS_KEY_SIZE} bits"
    echo "  Hash: $LUKS_HASH"
    if [[ -n "$ENCRYPTION_ITER_TIME" && "$ENCRYPTION_ITER_TIME" != "0" ]]; then
        echo "  Iteration Time: ${ENCRYPTION_ITER_TIME}ms"
    fi
    
    # Prompt for passphrase
    echo ""
    print_info "🔐 Enter encryption passphrase for LUKS:"
    
    # Build cryptsetup command
    local cryptsetup_cmd="cryptsetup -y -v --type $LUKS_TYPE --cipher $LUKS_CIPHER --key-size $LUKS_KEY_SIZE --hash $LUKS_HASH --use-random"
    
    # Add iteration time if specified
    if [[ -n "$ENCRYPTION_ITER_TIME" && "$ENCRYPTION_ITER_TIME" != "0" ]]; then
        cryptsetup_cmd="$cryptsetup_cmd --iter-time $ENCRYPTION_ITER_TIME"
    fi
    
    # Execute encryption
    eval "$cryptsetup_cmd luksFormat $lvm_partition" 2>&1 | tee -a "$LOG_FILE"
    
    if [[ $? -ne 0 ]]; then
        print_error "LUKS encryption setup failed"
        return 1
    fi
    
    # Open the encrypted partition
    print_status "Opening encrypted partition..."
    cryptsetup open "$lvm_partition" "${VG_NAME}" 2>&1 | tee -a "$LOG_FILE"
    
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
        # Determine LVM partition based on boot mode
        if [[ "$BOOT_MODE" == "uefi" ]]; then
            pv_device="${DISK}2"
        else
            pv_device="${DISK}3"
        fi
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
    
    # Mount boot and/or EFI partition based on boot mode
    if [[ "$BOOT_MODE" == "uefi" ]]; then
        mount "${DISK}1" "/mnt${EFI_MOUNT}"
    else
        mount "${DISK}2" /mnt/boot
    fi
    
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
    
    # Determine LVM partition based on boot mode
    local lvm_partition
    if [[ "$BOOT_MODE" == "uefi" ]]; then
        lvm_partition="${DISK}2"
    else
        lvm_partition="${DISK}3"
    fi
    
    # Get UUID of the encrypted partition
    local uuid=$(blkid -s UUID -o value "$lvm_partition")
    
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
    print_info "📊 Boot & Partition Layout Summary:"
    echo "  Boot Mode: $BOOT_MODE"
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
    echo "  5. Update GRUB for encryption and LVM support"
    if [[ "$BOOT_MODE" == "bios" ]]; then
        echo "  6. Note: BIOS boot - ensure disk signature is written (GPT Hybrid MBR)"
    fi
}

# ============================================
# Main Function
# ============================================

main() {
    clear
    print_info "🚀 Arch Linux Disk Partitioner with LVM + LUKS"
    print_info "============================================="
    echo ""
    
    # Detect boot mode
    detect_boot_mode
    echo ""
    
    # Load encryption preset if encryption is enabled
    if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
        load_encryption_preset "$ENCRYPTION_PRESET"
        echo ""
    fi
    
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
    
    # Create boot partitions based on boot mode
    if [[ "$BOOT_MODE" == "uefi" ]]; then
        create_efi_partition
    else
        create_bios_partitions
    fi
    
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