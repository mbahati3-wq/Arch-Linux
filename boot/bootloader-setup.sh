#!/usr/bin/bash

# ============================================
# Arch Linux GRUB Bootloader Setup
# Supports UEFI, LVM, and LUKS encryption
# ============================================

# Source color library
source ../lib/global-color.sh

# ============================================
# Configuration Variables
# ============================================

# Boot configuration
BOOT_MODE="${BOOT_MODE:-auto}"  # auto, uefi, bios
CHROOT_PATH="${CHROOT_PATH:-/mnt}"
EFI_MOUNT="${EFI_MOUNT:-/boot}"  # EFI partition mount point
BOOTLOADER_ID="${BOOTLOADER_ID:-GRUB}"

# LVM/LUKS configuration (auto-detected if not set)
VG_NAME="${VG_NAME:-vg0}"
LV_ROOT_NAME="${LV_ROOT_NAME:-lv_root}"
ENABLE_ENCRYPTION="${ENABLE_ENCRYPTION:-auto}"  # auto, true, false

# GRUB settings
GRUB_TIMEOUT="${GRUB_TIMEOUT:-5}"
GRUB_DEFAULT="${GRUB_DEFAULT:-0}"
GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT:-quiet splash}"

# Log file
BOOT_LOG="/tmp/bootloader_$(date +%Y%m%d_%H%M%S).log"

# ============================================
# Detection Functions
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
    fi
}

detect_encryption() {
    if [[ "$ENABLE_ENCRYPTION" == "auto" ]]; then
        if [[ -f "${CHROOT_PATH}/etc/crypttab" ]]; then
            ENABLE_ENCRYPTION="true"
            print_success "Detected LUKS encryption"
        else
            ENABLE_ENCRYPTION="false"
            print_info "No encryption detected"
        fi
    fi
}

detect_lvm() {
    if [[ -d "/dev/mapper" ]] && [[ -n "$(ls -A /dev/mapper 2>/dev/null)" ]]; then
        print_success "LVM detected"
        # Try to auto-detect VG name
        VG_NAME=$(ls /dev/mapper/ | grep -v "control" | head -1)
        return 0
    else
        print_info "No LVM detected"
        return 1
    fi
}

# ============================================
# GRUB Installation Functions
# ============================================

install_grub_uefi() {
    print_phase "Installing GRUB for UEFI"
    
    # Install required packages
    print_status "Installing GRUB and EFI tools..."
    arch-chroot "$CHROOT_PATH" /bin/bash -c "
        pacman -S --noconfirm --needed grub efibootmgr
    " 2>&1 | tee -a "$BOOT_LOG"
    
    # Install GRUB to EFI partition
    print_status "Installing GRUB to EFI partition..."
    arch-chroot "$CHROOT_PATH" /bin/bash -c "
        grub-install --target=x86_64-efi \
                     --efi-directory=${EFI_MOUNT} \
                     --bootloader-id=${BOOTLOADER_ID} \
                     --recheck
    " 2>&1 | tee -a "$BOOT_LOG"
    
    if [[ $? -eq 0 ]]; then
        print_success "GRUB installed successfully for UEFI"
    else
        print_error "GRUB installation failed"
        return 1
    fi
}

install_grub_bios() {
    print_phase "Installing GRUB for BIOS"
    
    # Detect the disk (parent of boot partition)
    local boot_disk=$(lsblk -no PKNAME "$(df "$CHROOT_PATH/boot" | tail -1 | awk '{print $1}')")
    
    # Install GRUB for BIOS
    print_status "Installing GRUB to disk: $boot_disk"
    arch-chroot "$CHROOT_PATH" /bin/bash -c "
        pacman -S --noconfirm --needed grub
        grub-install --target=i386-pc /dev/${boot_disk}
    " 2>&1 | tee -a "$BOOT_LOG"
    
    if [[ $? -eq 0 ]]; then
        print_success "GRUB installed successfully for BIOS"
    else
        print_error "GRUB installation failed"
        return 1
    fi
}

# ============================================
# GRUB Configuration Functions
# ============================================

configure_grub_encryption() {
    if [[ "$ENABLE_ENCRYPTION" != "true" ]]; then
        return 0
    fi
    
    print_phase "Configuring GRUB for LUKS Encryption"
    
    # Get UUID of encrypted partition
    local encrypted_uuid=$(blkid -s UUID -o value "$(findmnt -no SOURCE "$CHROOT_PATH/boot" | sed 's/2$/2/')" 2>/dev/null)
    
    if [[ -z "$encrypted_uuid" ]]; then
        # Try to find encrypted partition
        encrypted_uuid=$(blkid | grep "crypto_LUKS" | head -1 | sed -n 's/.*UUID="\([^"]*\)".*/\1/p')
    fi
    
    if [[ -n "$encrypted_uuid" ]]; then
        print_status "Found encrypted partition UUID: $encrypted_uuid"
        
        # Add cryptdevice to GRUB_CMDLINE_LINUX
        local cryptdevice="cryptdevice=UUID=${encrypted_uuid}:${VG_NAME}"
        
        # Update GRUB configuration
        arch-chroot "$CHROOT_PATH" /bin/bash -c "
            sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"${cryptdevice}\"/' /etc/default/grub
        " 2>&1 | tee -a "$BOOT_LOG"
        
        print_success "GRUB configured for LUKS encryption"
    else
        print_warning "Could not detect encrypted partition UUID"
    fi
}

configure_grub_lvm() {
    if ! detect_lvm; then
        return 0
    fi
    
    print_phase "Configuring GRUB for LVM"
    
    # Add LVM support to GRUB
    arch-chroot "$CHROOT_PATH" /bin/bash -c "
        sed -i 's/^GRUB_PRELOAD_MODULES=.*/GRUB_PRELOAD_MODULES=\"part_gpt part_msdos lvm\"/' /etc/default/grub
    " 2>&1 | tee -a "$BOOT_LOG"
    
    print_success "GRUB configured for LVM"
}

configure_grub_defaults() {
    print_phase "Configuring GRUB Defaults"
    
    # Set GRUB timeout
    arch-chroot "$CHROOT_PATH" /bin/bash -c "
        sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=${GRUB_TIMEOUT}/' /etc/default/grub
        sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=${GRUB_DEFAULT}/' /etc/default/grub
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"${GRUB_CMDLINE_LINUX_DEFAULT}\"/' /etc/default/grub
    " 2>&1 | tee -a "$BOOT_LOG"
    
    print_success "GRUB defaults configured"
}

generate_grub_config() {
    print_phase "Generating GRUB Configuration"
    
    # Generate main GRUB config
    arch-chroot "$CHROOT_PATH" /bin/bash -c "
        grub-mkconfig -o /boot/grub/grub.cfg
    " 2>&1 | tee -a "$BOOT_LOG"
    
    if [[ $? -eq 0 ]]; then
        print_success "GRUB configuration generated successfully"
        
        # Show detected operating systems
        print_info "Detected operating systems:"
        grep "menuentry" "${CHROOT_PATH}/boot/grub/grub.cfg" | sed 's/.*menuentry "\([^"]*\)".*/\1/' | head -5
    else
        print_error "Failed to generate GRUB configuration"
        return 1
    fi
}

# ============================================
# mkinitcpio Configuration
# ============================================

configure_mkinitcpio() {
    print_phase "Configuring mkinitcpio"
    
    local hooks="base udev autodetect modconf block"
    
    # Add LVM hook if needed
    if detect_lvm; then
        hooks="$hooks lvm2"
    fi
    
    # Add encrypt hook if needed
    if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
        hooks="$hooks encrypt"
    fi
    
    # Add filesystem hooks
    hooks="$hooks filesystems keyboard fsck"
    
    print_status "Setting mkinitcpio hooks: $hooks"
    
    arch-chroot "$CHROOT_PATH" /bin/bash -c "
        sed -i 's/^HOOKS=.*/HOOKS=(${hooks})/' /etc/mkinitcpio.conf
        mkinitcpio -p linux
    " 2>&1 | tee -a "$BOOT_LOG"
    
    if [[ $? -eq 0 ]]; then
        print_success "mkinitcpio configured successfully"
    else
        print_error "Failed to configure mkinitcpio"
        return 1
    fi
}

# ============================================
# Fallback and Recovery Options
# ============================================

create_grub_rescue() {
    print_phase "Creating GRUB Rescue Options"
    
    # Create a custom rescue entry
    cat > "${CHROOT_PATH}/etc/grub.d/40_custom" << 'EOF'
#!/bin/sh
exec tail -n +3 $0
# This file provides an easy way to add custom menu entries.

menuentry "System Recovery (Fallback)" {
    echo "Loading fallback kernel..."
    linux /vmlinuz-linux root=/dev/mapper/vg0-lv_root ro
    echo "Loading fallback initramfs..."
    initrd /initramfs-linux-fallback.img
}

menuentry "System Recovery (LTS Kernel)" {
    echo "Loading LTS kernel..."
    linux /vmlinuz-linux-lts root=/dev/mapper/vg0-lv_root ro
    echo "Loading LTS initramfs..."
    initrd /initramfs-linux-lts.img
}

menuentry "Firmware Setup (UEFI)" {
    fwsetup
}

menuentry "Memory Test (Memtest86+)" {
    linux16 /boot/memtest86+/memtest.bin
}
EOF
    
    arch-chroot "$CHROOT_PATH" chmod +x /etc/grub.d/40_custom
    
    # Regenerate GRUB config with rescue entries
    generate_grub_config
    
    print_success "GRUB rescue entries created"
}

# ============================================
# EFI Boot Management
# ============================================

manage_efi_boot_entries() {
    if [[ "$BOOT_MODE" != "uefi" ]]; then
        return 0
    fi
    
    print_phase "Managing EFI Boot Entries"
    
    # List current EFI boot entries
    print_status "Current EFI boot entries:"
    efibootmgr -v 2>&1 | tee -a "$BOOT_LOG"
    
    # Set GRUB as default boot entry
    local grub_bootnum=$(efibootmgr -v | grep -i "$BOOTLOADER_ID" | sed -n 's/Boot\([0-9A-F]*\).*/\1/p')
    if [[ -n "$grub_bootnum" ]]; then
        print_status "Setting GRUB (Boot${grub_bootnum}) as default..."
        efibootmgr -o "$grub_bootnum" 2>&1 | tee -a "$BOOT_LOG"
        print_success "Default boot entry set to GRUB"
    fi
    
    # Create backup boot entry
    print_status "Creating backup boot entry..."
    efibootmgr -c -d /dev/sda -p 1 -L "Arch Linux Backup" -l '\EFI\GRUB\grubx64.efi' 2>&1 | tee -a "$BOOT_LOG"
}

# ============================================
# Verification Functions
# ============================================

verify_bootloader() {
    print_phase "Verifying Bootloader Installation"
    
    # Check if GRUB files exist
    if [[ -f "${CHROOT_PATH}/boot/grub/grub.cfg" ]]; then
        print_success "✓ GRUB configuration exists"
    else
        print_error "✗ GRUB configuration missing"
        return 1
    fi
    
    # Check EFI boot files for UEFI
    if [[ "$BOOT_MODE" == "uefi" ]]; then
        if [[ -f "${CHROOT_PATH}${EFI_MOUNT}/EFI/${BOOTLOADER_ID}/grubx64.efi" ]]; then
            print_success "✓ EFI boot file exists"
        else
            print_warning "✗ EFI boot file not found"
        fi
    fi
    
    # Verify initramfs
    if [[ -f "${CHROOT_PATH}/boot/initramfs-linux.img" ]]; then
        print_success "✓ Initramfs exists"
    else
        print_error "✗ Initramfs missing"
        return 1
    fi
    
    print_success "Bootloader verification complete"
}

# ============================================
# Summary Function
# ============================================

show_bootloader_summary() {
    echo ""
    print_success "=========================================="
    print_success "✅ BOOTLOADER SETUP COMPLETE"
    print_success "=========================================="
    echo ""
    print_info "📊 Boot Configuration:"
    echo "  Boot Mode: $BOOT_MODE"
    echo "  Encryption: $ENABLE_ENCRYPTION"
    echo "  LVM: $(detect_lvm && echo 'Enabled' || echo 'Disabled')"
    echo "  GRUB Timeout: ${GRUB_TIMEOUT}s"
    echo ""
    print_info "📝 Log File: $BOOT_LOG"
    echo ""
    print_warning "⚠️  Next Steps:"
    echo "  1. Exit chroot: exit"
    echo "  2. Unmount partitions: umount -R /mnt"
    echo "  3. Reboot: reboot"
    echo "  4. Remove installation media"
}

# ============================================
# Main Function
# ============================================

main() {
    clear
    print_info "🚀 Arch Linux Bootloader Setup"
    print_info "==============================="
    echo ""
    
    # Verify running in chroot or with chroot access
    if [[ ! -d "$CHROOT_PATH" ]]; then
        print_error "Chroot path $CHROOT_PATH does not exist"
        exit 1
    fi
    
    # Detect system configuration
    detect_boot_mode
    detect_encryption
    detect_lvm
    
    # Install GRUB based on boot mode
    if [[ "$BOOT_MODE" == "uefi" ]]; then
        install_grub_uefi || exit 1
    else
        install_grub_bios || exit 1
    fi
    
    # Configure GRUB
    configure_grub_defaults
    configure_grub_encryption
    configure_grub_lvm
    
    # Configure mkinitcpio
    configure_mkinitcpio
    
    # Generate GRUB configuration
    generate_grub_config
    
    # Create rescue options
    create_grub_rescue
    
    # Manage EFI boot entries (UEFI only)
    if [[ "$BOOT_MODE" == "uefi" ]]; then
        manage_efi_boot_entries
    fi
    
    # Verify installation
    verify_bootloader
    
    # Show summary
    show_bootloader_summary
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (sudo)"
        exit 1
    fi
    
    main "$@"
fi