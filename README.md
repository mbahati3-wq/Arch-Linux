# Arch Linux Automated Installation Suite

A comprehensive, modular Bash automation framework for setting up Arch Linux from scratch with support for advanced configurations including LVM, LUKS encryption, and multiple boot modes.

## 🎯 Features

- **Full Disk Automation**: Automated partitioning with GPT/UEFI support
- **LVM Support**: Logical Volume Management with customizable partitions (root, home, var, swap)
- **LUKS Encryption**: Optional full-disk encryption with sector key management
- **Multiple Boot Modes**: Automatic detection and configuration for UEFI, BIOS/Legacy boot
- **GRUB Bootloader**: Comprehensive GRUB configuration with encryption support
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
- Creates GPT partition table
- Configures EFI partition (512 MiB)
- Sets up LVM physical volumes
- Creates logical volumes for root, home, var, and swap
- Optionally encrypts logical volumes with LUKS
- Formats filesystems (EXT4 for Linux partitions, FAT32 for EFI)

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
DISK="/dev/sda"                    # Target disk
EFI_SIZE="512"                     # EFI partition size (MiB)
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

# Encryption
ENABLE_ENCRYPTION="true"           # Enable LUKS encryption
LUKS_TYPE="luks2"                  # LUKS version
LUKS_CIPHER="aes-xts-plain64"      # Encryption cipher
LUKS_KEY_SIZE="512"                # Key size (bits)
LUKS_HASH="sha512"                 # Hash algorithm
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
git clone <repo-url>
cd Arch-Linux

# 3. Review and modify configuration in main.sh
vim main.sh

# 4. Run the main installation script
sudo ./main.sh
```

### Step-by-Step Manual Execution

```bash
# Stage 1: Partition and format disk
sudo DISK="/dev/sda" ./disk/partitioner.sh

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

**Issue**: Disk not found
```
Solution: Verify device path with: lsblk
         Update DISK variable in main.sh
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

## 🔄 Errors Fixed in This Version

1. ✅ Fixed stray `.` character in main.sh causing syntax error
2. ✅ Fixed incorrect library reference in logger.sh (`colorful.sh` → `color.sh`)
3. ✅ Fixed relative path sourcing in subdirectory scripts using absolute paths
4. ✅ Added missing `print_phase()` function to global-color.sh library
5. ✅ Proper path handling for scripts run from different contexts

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
**Status**: Stable