#!/usr/bin/bash

# ============================================
# Arch Linux Minimal Package Installer
# Installs base system and essential packages
# ============================================

# Source color library
source ../lib/global-color.sh

# ============================================
# Configuration Variables
# ============================================

# Package categories (easily customizable)
BASE_PACKAGES=(
    "base"
    "base-devel"
    "linux"
    "linux-lts"           # LTS kernel as backup
    "linux-firmware"
    "linux-headers"
)

ESSENTIAL_PACKAGES=(
    "vim"
    "nano"
    "git"
    "curl"
    "wget"
    "htop"
    "tree"
    "man-db"
    "man-pages"
    "texinfo"
)

NETWORK_PACKAGES=(
    "networkmanager"
    "iwd"                  # Wireless daemon
    "dhcpcd"
    "openssh"
    "iptables-nft"
)

SYSTEM_UTILITIES=(
    "sudo"
    "which"
    "psmisc"
    "lsof"
    "unzip"
    "zip"
    "tar"
    "gzip"
    "bzip2"
    "xz"
    "zstd"
)

LVM_PACKAGES=(
    "lvm2"
)

ENCRYPTION_PACKAGES=(
    "cryptsetup"
)

FILESYSTEM_PACKAGES=(
    "e2fsprogs"           # ext4 tools
    "dosfstools"          # FAT tools
    "ntfs-3g"             # NTFS support
    "exfat-utils"         # exFAT support
)

FIRMWARE_PACKAGES=(
    "amd-ucode"           # AMD CPU microcode
    "intel-ucode"         # Intel CPU microcode
)

# Installation mode (minimal, server, desktop)
INSTALL_MODE="${INSTALL_MODE:-minimal}"  # minimal, server, desktop

# Chroot path (where system is mounted)
CHROOT_PATH="${CHROOT_PATH:-/mnt}"

# Log file
PACKAGE_LOG="/tmp/package_install_$(date +%Y%m%d_%H%M%S).log"

# ============================================
# Helper Functions
# ============================================

log_package() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$PACKAGE_LOG"
}

check_package_installation() {
    local package="$1"
    if pacman -Q "$package" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

install_packages() {
    local packages=("$@")
    local failed_packages=()
    
    for package in "${packages[@]}"; do
        if check_package_installation "$package"; then
            print_info "✅ Package already installed: $package"
            log_package "Package already installed: $package"
        else
            print_status "📦 Installing: $package"
            if pacstrap "$CHROOT_PATH" "$package" 2>&1 | tee -a "$PACKAGE_LOG"; then
                print_success "✓ Installed: $package"
                log_package "Successfully installed: $package"
            else
                print_error "✗ Failed to install: $package"
                log_package "FAILED to install: $package"
                failed_packages+=("$package")
            fi
        fi
    done
    
    # Report failed packages
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        print_warning "Failed to install ${#failed_packages[@]} packages:"
        printf '%s\n' "${failed_packages[@]}"
        return 1
    fi
    
    return 0
}

install_aur_helper() {
    print_status "Installing AUR helper (yay)..."
    
    # Install dependencies for building
    arch-chroot "$CHROOT_PATH" /bin/bash -c "
        pacman -S --noconfirm --needed git base-devel
    "
    
    # Clone and build yay
    arch-chroot "$CHROOT_PATH" /bin/bash -c "
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd /
        rm -rf /tmp/yay
    " 2>&1 | tee -a "$PACKAGE_LOG"
    
    if [[ $? -eq 0 ]]; then
        print_success "AUR helper (yay) installed successfully"
    else
        print_error "Failed to install AUR helper"
    fi
}

# ============================================
# Installation Phases
# ============================================

phase_base_installation() {
    print_phase "Phase 1: Installing Base System"
    
    # Install base packages
    install_packages "${BASE_PACKAGES[@]}"
    
    # Install CPU microcode
    local cpu_vendor=$(lscpu | grep "Vendor ID" | awk '{print $3}')
    if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
        install_packages "intel-ucode"
    elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
        install_packages "amd-ucode"
    fi
    
    print_success "Base system installation complete"
}

phase_essential_packages() {
    print_phase "Phase 2: Installing Essential Packages"
    
    install_packages "${ESSENTIAL_PACKAGES[@]}"
    install_packages "${SYSTEM_UTILITIES[@]}"
    
    print_success "Essential packages installed"
}

phase_network_setup() {
    print_phase "Phase 3: Setting up Networking"
    
    install_packages "${NETWORK_PACKAGES[@]}"
    
    # Enable NetworkManager
    arch-chroot "$CHROOT_PATH" systemctl enable NetworkManager 2>&1 | tee -a "$PACKAGE_LOG"
    
    # Enable SSH if installed
    if check_package_installation "openssh"; then
        arch-chroot "$CHROOT_PATH" systemctl enable sshd 2>&1 | tee -a "$PACKAGE_LOG"
    fi
    
    print_success "Network setup complete"
}

phase_storage_support() {
    print_phase "Phase 4: Installing Storage Support"
    
    # Install LVM if LVM was used
    if [[ -d "/dev/mapper" ]] && [[ -n "$(ls -A /dev/mapper 2>/dev/null)" ]]; then
        print_info "LVM detected, installing LVM packages"
        install_packages "${LVM_PACKAGES[@]}"
        
        # Enable LVM service
        arch-chroot "$CHROOT_PATH" systemctl enable lvm2-monitor 2>&1 | tee -a "$PACKAGE_LOG"
    fi
    
    # Install filesystem tools
    install_packages "${FILESYSTEM_PACKAGES[@]}"
    
    # Check if encryption was used
    if [[ -f "/mnt/etc/crypttab" ]]; then
        print_info "Encryption detected, installing cryptsetup"
        install_packages "${ENCRYPTION_PACKAGES[@]}"
    fi
    
    print_success "Storage support installed"
}

phase_server_packages() {
    if [[ "$INSTALL_MODE" == "server" ]] || [[ "$INSTALL_MODE" == "desktop" ]]; then
        print_phase "Phase 5: Installing Server Packages"
        
        local SERVER_PACKAGES=(
            "nginx"               # Web server
            "mariadb"             # Database
            "php"                 # PHP
            "php-fpm"            # PHP FastCGI
            "redis"              # Cache
            "docker"             # Containerization
            "docker-compose"     # Container orchestration
            "fail2ban"           # Security
            "ufw"                # Firewall
        )
        
        install_packages "${SERVER_PACKAGES[@]}"
        
        # Enable services
        arch-chroot "$CHROOT_PATH" systemctl enable docker 2>&1 | tee -a "$PACKAGE_LOG"
        arch-chroot "$CHROOT_PATH" systemctl enable fail2ban 2>&1 | tee -a "$PACKAGE_LOG"
        
        print_success "Server packages installed"
    fi
}

phase_desktop_packages() {
    if [[ "$INSTALL_MODE" == "desktop" ]]; then
        print_phase "Phase 6: Installing Desktop Environment"
        
        local DESKTOP_PACKAGES=(
            # Display Server
            "xorg-server"
            "xorg-apps"
            "xorg-drivers"
            "xorg-xinit"
            
            # Display Manager
            "lightdm"
            "lightdm-gtk-greeter"
            
            # Desktop Environment (XFCE - Lightweight)
            "xfce4"
            "xfce4-goodies"
            
            # Audio
            "pipewire"
            "pipewire-pulse"
            "wireplumber"
            "alsa-utils"
            
            # Fonts
            "ttf-dejavu"
            "ttf-liberation"
            "noto-fonts"
            "noto-fonts-emoji"
            
            # Browser
            "firefox"
            
            # Terminal
            "alacritty"
            
            # File Manager
            "thunar"
            "thunar-archive-plugin"
            "thunar-media-tags-plugin"
            
            # System Tools
            "gnome-disk-utility"
            "gparted"
            "htop"
            "neofetch"
        )
        
        install_packages "${DESKTOP_PACKAGES[@]}"
        
        # Enable display manager
        arch-chroot "$CHROOT_PATH" systemctl enable lightdm 2>&1 | tee -a "$PACKAGE_LOG"
        
        # Enable audio service
        arch-chroot "$CHROOT_PATH" systemctl --user enable pipewire pipewire-pulse 2>&1 | tee -a "$PACKAGE_LOG"
        
        print_success "Desktop environment installed"
    fi
}

phase_post_install() {
    print_phase "Phase 7: Post-Installation Configuration"
    
    # Create swap file if needed (not using LVM swap)
    if [[ ! -d "/dev/mapper" ]]; then
        print_info "Creating swap file (2GB)..."
        arch-chroot "$CHROOT_PATH" /bin/bash -c "
            dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
        " 2>&1 | tee -a "$PACKAGE_LOG"
    fi
    
    # Update package database
    arch-chroot "$CHROOT_PATH" pacman -Sy 2>&1 | tee -a "$PACKAGE_LOG"
    
    # Install AUR helper for desktop mode
    if [[ "$INSTALL_MODE" == "desktop" ]]; then
        install_aur_helper
    fi
    
    print_success "Post-installation complete"
}

# ============================================
# Summary Function
# ============================================

show_installation_summary() {
    echo ""
    print_success "=========================================="
    print_success "✅ PACKAGE INSTALLATION COMPLETE"
    print_success "=========================================="
    echo ""
    print_info "📦 Installed Packages:"
    arch-chroot "$CHROOT_PATH" pacman -Q | wc -l | xargs echo "  Total packages:"
    echo ""
    print_info "🔧 Enabled Services:"
    arch-chroot "$CHROOT_PATH" systemctl list-unit-files | grep enabled | head -10 | tee -a "$PACKAGE_LOG"
    echo ""
    print_info "📝 Package Log: $PACKAGE_LOG"
    echo ""
    print_warning "⚠️  Next Steps:"
    echo "  1. Set root password: arch-chroot $CHROOT_PATH passwd"
    echo "  2. Create user: arch-chroot $CHROOT_PATH useradd -m username"
    echo "  3. Set user password: arch-chroot $CHROOT_PATH passwd username"
    echo "  4. Configure sudo: visudo"
    echo "  5. Setup bootloader (run bootloader-setup.sh)"
    echo "  6. Reboot system"
}

# ============================================
# Main Function
# ============================================

main() {
    clear
    print_info "🚀 Arch Linux Package Installer"
    print_info "================================"
    echo ""
    print_info "Installation Mode: $INSTALL_MODE"
    print_info "Target Path: $CHROOT_PATH"
    echo ""
    
    # Verify chroot path exists
    if [[ ! -d "$CHROOT_PATH" ]]; then
        print_error "Chroot path $CHROOT_PATH does not exist"
        exit 1
    fi
    
    # Run installation phases
    phase_base_installation
    phase_essential_packages
    phase_network_setup
    phase_storage_support
    phase_server_packages
    phase_desktop_packages
    phase_post_install
    
    # Show summary
    show_installation_summary
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