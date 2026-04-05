# Arch Linux Automated Installation Suite

A comprehensive, modular Bash automation framework for setting up Arch Linux from scratch with support for advanced configurations including LVM, LUKS encryption, and multiple boot modes (UEFI and BIOS/Legacy).

## 🎯 Features

- **Full Disk Automation**: Automated partitioning with GPT/UEFI and MBR/BIOS support
- **Automatic Boot Mode Detection**: Automatically detects and configures for your system (UEFI, BIOS/Legacy)
- **LVM Support**: Logical Volume Management with customizable partitions (root, home, var, swap)
- **LUKS Encryption**: Optional full-disk encryption with sector key management
- **Flexible Boot Configuration**: 
  - **UEFI**: GPT partition table with EFI System Partition (FAT32)
  - **BIOS**: MBR partition table with BIOS Boot Partition and separate /boot
- **GRUB Bootloader**: Comprehensive GRUB configuration with encryption support for both boot modes
- **Package Management**: Flexible package installation with multiple profiles (minimal, server, desktop)
- **Logging**: Dual-output logging system (console + persistent logs)
- **Colorful Output**: Rich, informative console output with icons and colors
- **Modular Design**: Easily customizable components with configuration variables

## 📁 Project Structure

```
Arch-Linux/
├── boot/
│   └── bootloader-setup.sh      # GRUB installation and configuration
├── disk/
│   ├── config-lvm.sh             # Post-installation LVM/LUKS configuration
│   └── partitioner.sh            # Disk partitioning with LVM + LUKS support
├── lib/
│   ├── color.sh                  # Basic color definitions
│   ├── global-color.sh           # Advanced logging and color functions
│   └── logger.sh                 # Logging infrastructure
├── packages/
│   └── package-installer.sh      # Package installation management
├── main.sh                       # Main installation orchestrator
└── README.md                     # This file
```

## 🔧 Prerequisites

- Arch Linux ISO running in live environment
- Partition tools: `parted`, `fdisk`, `lsblk`
- LVM tools: `pvcreate`, `vgcreate`, `lvcreate`
- Encryption tools: `cryptsetup`
- Standard utilities: `bash`, `grep`, `sed`, `awk`

## 📋 Installation Overview

The installation process consists of three main stages:

### Stage 1: Disk Partitioning

#### For UEFI Systems (GPT Partition Table):
- Creates GPT partition table
- Configures EFI System Partition (512 MiB, FAT32)
- Sets up LVM physical volumes
- Creates logical volumes for root, home, var, and swap
- Optionally encrypts logical volumes with LUKS
- Formats filesystems appropriately

#### For BIOS/Legacy Systems (MBR Partition Table):
- Creates MBR partition table
- Configures BIOS Boot Partition (2 MiB, unformatted) - required by GRUB
- Creates /boot partition (512 MiB, ext4) - separate from root
- Sets up LVM physical volumes
- Creates logical volumes for root, home, var, and swap
- Optionally encrypts logical volumes with LUKS
- Formats filesystems appropriately

**Boot Mode Detection**: The system automatically detects whether the live environment is UEFI or BIOS and adjusts partitioning accordingly. You can also force a specific mode with `BOOT_MODE="uefi"` or `BOOT_MODE="bios"`.

### Stage 2: Package Installation
- Installs base system and base-development packages
- Installs multiple kernel options (linux + linux-lts)
- Installs essential utilities (vim, git, curl, wget, etc.)
- Installs firmware packages
- Configures networking components
- Installs filesystem tools for multiple formats

### Stage 3: Bootloader Setup
- Detects boot mode (UEFI vs BIOS)
- Installs GRUB bootloader
- Configures GRUB for LVM and encryption support
- Generates `mkinitcpio` with appropriate hooks
- Creates GRUB configuration with rescue options

## ⚙️ Configuration

### Main Configuration (main.sh)

```bash
DISK="/dev/sda"                    # Target disk device
INSTALL_MODE="desktop"             # minimal, server, or desktop
```

### Disk Partitioning (disk/partitioner.sh)

```bash
# Boot mode configuration
BOOT_MODE="auto"                   # auto, uefi, or bios (auto-detects)
DISK="/dev/sda"                    # Target disk
EFI_SIZE="512"                     # EFI partition size (MiB) - UEFI only
BIOS_BOOT_SIZE="2"                 # BIOS boot partition size (MiB) - BIOS only
SWAP_SIZE="8192"                   # Swap size (MiB) - 8GB default

# LVM Volume names
VG_NAME="vg0"                      # Volume Group name
LV_ROOT_NAME="lv_root"             # Root logical volume
LV_HOME_NAME="lv_home"             # Home logical volume
LV_VAR_NAME="lv_var"               # Var logical volume
LV_SWAP_NAME="lv_swap"             # Swap logical volume

# Size allocations (GiB)
ROOT_SIZE="30"                     # Root partition
HOME_SIZE="100"                    # Home partition
VAR_SIZE="20"                      # Var partition

# Encryption Configuration
ENABLE_ENCRYPTION="true"           # Enable LUKS encryption (true/false)
ENCRYPTION_PRESET="standard"       # Encryption preset: standard, paranoid, performance, legacy
# OR manually configure:
LUKS_TYPE="luks2"                  # LUKS version (luks1 or luks2)
LUKS_CIPHER="aes-xts-plain64"      # Encryption cipher
LUKS_KEY_SIZE="512"                # Key size (bits)
LUKS_HASH="sha512"                 # Hash algorithm
ENCRYPTION_ITER_TIME="0"           # Iteration time (ms), 0 = default
```

### Bootloader Configuration (boot/bootloader-setup.sh)

```bash
BOOT_MODE="auto"                   # auto, uefi, or bios
CHROOT_PATH="/mnt"                 # Chroot mount path
EFI_MOUNT="/boot"                  # EFI mount point
BOOTLOADER_ID="GRUB"               # Boot manager ID

# GRUB settings
GRUB_TIMEOUT="5"                   # Timeout seconds
GRUB_DEFAULT="0"                   # Default menu entry
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"  # Kernel parameters
```

### Package Installation Modes (packages/package-installer.sh)

- **minimal**: Core system only
- **server**: Minimal + networking/SSH
- **desktop**: Server + desktop environment packages

## 🚀 Usage

### Quick Start

```bash
# 1. Boot from Arch Linux ISO
# 2. Clone or fetch this repository
git clone https://github.com/mbahati3-wq/Arch-Linux.git 
cd Arch-Linux

# 3. Review and modify configuration in main.sh
vim main.sh

# 4. Run the main installation script
sudo ./main.sh
```

### Boot Mode Configuration

The script automatically detects your boot mode (UEFI or BIOS), but you can override it:

```bash
# For UEFI systems (default on modern hardware)
sudo BOOT_MODE="uefi" ./main.sh

# For BIOS/Legacy systems
sudo BOOT_MODE="bios" ./main.sh

# Auto-detect (recommended)
sudo BOOT_MODE="auto" ./main.sh
```

**BIOS-Specific Notes:**
- BIOS Boot Partition (2 MiB) must exist for GRUB to install properly
- /boot partition is separate from root and is essential for kernel loading
- MBR partition table limits disk size to 2TB (use UEFI for larger disks)
- Legacy BIOS systems boot through MBR boot sector

### Encryption Configuration

The script supports multiple encryption presets optimized for different security needs:

```bash
# Standard encryption (recommended, default)
sudo ENCRYPTION_PRESET="standard" ./main.sh

# Paranoid mode (maximum security, slower unlock)
sudo ENCRYPTION_PRESET="paranoid" ./main.sh

# Performance mode (balanced speed)
sudo ENCRYPTION_PRESET="performance" ./main.sh

# Legacy mode (LUKS1 for old systems)
sudo ENCRYPTION_PRESET="legacy" ./main.sh

# Disable encryption
sudo ENABLE_ENCRYPTION="false" ./main.sh
```

**Encryption Presets:**
- **Standard** (recommended): AES-256-XTS, SHA512, LUKS2 - best for most systems
- **Paranoid**: AES-256-XTS, SHA512, LUKS2, 4000ms iterations - maximum security for sensitive data
- **Performance**: AES-128-XTS, SHA256, LUKS2, 1000ms - optimized for speed
- **Legacy**: AES-256-XTS, SHA1, LUKS1 - for very old systems

See [CRYPTSETUP_GUIDE.md](CRYPTSETUP_GUIDE.md) for detailed encryption documentation.

### Step-by-Step Manual Execution

```bash
# Stage 1: Partition and format disk (auto-detects UEFI/BIOS)
sudo DISK="/dev/sda" ./disk/partitioner.sh

# Or force specific boot mode
sudo DISK="/dev/sda" BOOT_MODE="bios" ./disk/partitioner.sh

# Stage 2: Install packages
sudo INSTALL_MODE="desktop" ./packages/package-installer.sh

# Stage 3: Configure bootloader
sudo ./boot/bootloader-setup.sh
```

### Environment Variables

Most components accept environment variable overrides:

```bash
# Override from command line
sudo DISK="/dev/nvme0n1" INSTALL_MODE="server" ./main.sh

# Or set before sourcing
export ENABLE_ENCRYPTION="false"
sudo ./main.sh
```

## 📊 Logging

All components write logs to multiple destinations:

- **Console**: Colorful, formatted output with icons
- **Log Files**: `/logs/` directory (created at runtime)
  - `console_YYYYMMDD_HHMMSS.log` - Complete session log
  - `error_YYYYMMDD_HHMMSS.log` - Error-only log

### Log Analysis

View log files:
```bash
cat logs/console_*.log
tail -f logs/console_*.log  # Real-time monitoring
grep "ERROR" logs/error_*.log
```

## 🔍 Troubleshooting

### Common Issues

**Issue**: GRUB installation fails on BIOS systems
```
Solution: Verify BIOS boot partition exists (${DISK}1)
         Check partition flags: parted /dev/sda print
         Ensure BIOS Boot Partition is 2 MiB unformatted
         Verify /boot is mounted properly: mount | grep /boot
```

**Issue**: System won't boot from BIOS partition
```
Solution: Ensure BIOS Boot Partition has correct flags
         Run: parted /dev/sda set 1 bios_grub on
         Verify with: parted /dev/sda print
```

**Issue**: Disk not found
```
Solution: Verify device path with: lsblk
         Update DISK variable in main.sh or pass via env
```

**Issue**: Encryption password not accepted
```
Solution: Use strong passwords
         Verify keyboard layout matches expectations
         Check encryption setup with: cryptsetup luksDump
```

**Issue**: GRUB installation fails on UEFI systems
```
Solution: Verify EFI partition exists and is mounted at /boot
         Check EFI firmware with: ls -la /sys/firmware/efi
```

**Issue**: Missing packages after installation
```
Solution: Verify INSTALL_MODE is correct
         Check package-installer.sh logs for failures
         Manually install missing packages with: pacman -S <package>
```

### Debug Mode

Enable verbose logging:
```bash
export DEBUG_MODE="1"
export LOG_LEVEL="7"  # 7 = Debug, 6 = Info, 3 = Error
sudo ./main.sh
```

## 🛡️ Security Considerations

- LUKS encryption uses strong defaults (AES-256-XTS with SHA512)
- Root filesystem is separate from home (allows easier reinstallation)
- Swap is encrypted when LUKS is enabled
- `/var` is separate for safer system upgrades
- EFI partition is separate for UEFI boot compatibility

## 📝 Log File Locations

- **Session logs**: `./logs/console_YYYYMMDD_HHMMSS.log`
- **Error logs**: `./logs/error_YYYYMMDD_HHMMSS.log`
- **Temporary logs**: `/tmp/partitioning_*.log`, `/tmp/package_install_*.log`, `/tmp/bootloader_*.log`

## 🔄 Errors Fixed & Features Added

### Previous Fixes:
1. ✅ Fixed stray `.` character in main.sh causing syntax error
2. ✅ Fixed incorrect library reference in logger.sh (`colorful.sh` → `color.sh`)
3. ✅ Fixed relative path sourcing in subdirectory scripts using absolute paths
4. ✅ Added missing `print_phase()` function to global-color.sh library
5. ✅ Proper path handling for scripts run from different contexts

### New Features Added:
6. ✅ **BIOS/Legacy Boot Support**: Complete BIOS-bootable system with MBR partition table
7. ✅ **Boot Mode Auto-Detection**: Automatically detects UEFI or BIOS and configures accordingly
8. ✅ **Flexible Boot Configuration**: Works seamlessly on both modern UEFI and legacy BIOS systems
9. ✅ **Separate /boot Partition for BIOS**: Creates dedicated boot partition for BIOS systems
10. ✅ **BIOS Boot Partition Management**: Proper BIOS boot partition configuration for GRUB

## 📚 Additional Resources

- [Arch Linux Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
- [LVM on Linux](https://wiki.archlinux.org/title/LVM)
- [Disk Encryption](https://wiki.archlinux.org/title/Dm-crypt)
- [GRUB Configuration](https://wiki.archlinux.org/title/GRUB)

## ⚠️ Important Notes

- **Backup**: This script will partition your disk. **Back up your data first!**
- **Testing**: Test in a virtual machine before using on physical hardware
- **Permissions**: Must be run with `sudo` for disk operations
- **Network**: Requires internet connection for package downloads
- **Chroot**: Post-installation configuration is done inside a chroot environment

## 📄 License

This project is provided as-is for educational and personal use.

---

**Last Updated**: April 5, 2026  
**Version**: 1.0.0  
**Status**: Stable\



# Auto-detect boot mode (recommended)
sudo ./main.sh

# Force BIOS mode
sudo BOOT_MODE="bios" ./main.sh

# Force UEFI mode
sudo BOOT_MODE="uefi" ./main.sh