#!/usr/bin/bash

# Source color library
source lib/global-color.sh

# Configuration
DISK="/dev/sda"
INSTALL_MODE="desktop"  # minimal, server, desktop

print_info "Starting Complete Arch Linux Installation"

# Step 1: Partition disk
print_status "Step 1: Partitioning disk..."
sudo DISK="$DISK" ./disk/partitioner.sh || exit 1

# Step 2: Install packages
print_status "Step 2: Installing packages..."
sudo INSTALL_MODE="$INSTALL_MODE" ./packages/package-installer.sh || exit 1

# Step 3: Setup bootloader
print_status "Step 3: Setting up bootloader..."
sudo ./boot/bootloader-setup.sh || exit 1

print_success "Installation Complete! System ready for reboot."