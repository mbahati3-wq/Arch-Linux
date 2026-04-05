#!/usr/bin/bash

# ============================================
# Post-Installation LVM/LUKS Configuration
# Run this inside arch-chroot
# ============================================

source ../lib/global-color.sh

# Configuration (match your partitioner settings)
VG_NAME="${VG_NAME:-vg0}"
ENABLE_ENCRYPTION="${ENABLE_ENCRYPTION:-true}"

print_status "Configuring mkinitcpio for LVM/LUKS..."

# Configure mkinitcpio
if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    # Add encrypt and lvm2 hooks
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
    print_success "Added encrypt and lvm2 hooks to mkinitcpio"
else
    # Add only lvm2 hook
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
    print_success "Added lvm2 hooks to mkinitcpio"
fi

# Regenerate initramfs
print_status "Regenerating initramfs..."
mkinitcpio -p linux

# Configure GRUB for encryption
if [[ "$ENABLE_ENCRYPTION" == "true" ]]; then
    print_status "Configuring GRUB for encryption..."
    
    # Get UUID of encrypted partition
    ENCRYPTED_UUID=$(blkid -s UUID -o value "${DISK}2")
    
    # Add cryptdevice parameter to GRUB
    sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${ENCRYPTED_UUID}:${VG_NAME} root=/dev/${VG_NAME}/${LV_ROOT_NAME}\"|" /etc/default/grub
    
    print_success "GRUB configured for encryption"
fi

# Install and configure GRUB
print_status "Installing GRUB..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

print_success "Bootloader configured successfully"
print_info "System is ready for reboot!"